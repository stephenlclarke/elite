"""Offline asset execution/cleanup regressions; no renderer, process query or signal runs."""
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import tempfile
import sys
from contextlib import contextmanager
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('media_reference',Path(__file__).with_name('ship-reference.py'))
media=importlib.util.module_from_spec(spec);spec.loader.exec_module(media)
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/'Tools/CI'))
from recoverable_shards import worker_limit


class Process:
    pid=10
    def __init__(self,code=None):self.returncode=code;self.waits=[]
    def poll(self):return self.returncode
    def wait(self,timeout):self.waits.append(timeout);return self.returncode


def row(parent=1,start='original',rss=1024,group=10):
    return {'parent':parent,'group':group,'start':start,'rss':rss}


class ExecutionTests(unittest.TestCase):
    def run_case(self,process,rows=None,clock=1,log=None,cleanup=True,poll_error=None):
        if poll_error:process.poll=lambda:(_ for _ in ()).throw(poll_error)
        with patch.object(media.subprocess,'Popen',return_value=process) as spawn,\
             patch.object(media,'process_memory',side_effect=rows if isinstance(rows,Exception) else None,
                          return_value=rows or {}),\
             patch.object(media,'stop_renderer',return_value=(cleanup,False)) as stop,\
             patch.object(media.time,'monotonic',side_effect=clock if callable(clock) else None,return_value=clock),\
             patch.object(media.time,'sleep'),patch('sys.stderr',io.StringIO()):
            result=media.run_renderer(['swift','run','Elite'],Path('/workspace'),log or io.BytesIO(),[3,4],10)
        return result,spawn,stop

    def test_metadata_failure_cleans_child_and_returns_failure_without_custody_or_hold(self):
        process=Process();code,spawn,stop=self.run_case(process,RuntimeError('metadata failed'))
        self.assertEqual(code,1);stop.assert_called_once()
        self.assertTrue(spawn.call_args.kwargs['start_new_session'])
        self.assertEqual(spawn.call_args.kwargs['pass_fds'],(3,4))

    def test_timeout_reserves_cleanup_within_original_deadline(self):
        times=iter([1,9])
        code,_,stop=self.run_case(Process(),clock=lambda:next(times,9))
        self.assertEqual(code,124);self.assertEqual(stop.call_args.args[-1],10)

    def test_rss_breach_is_failure_and_always_cleans(self):
        code,_,stop=self.run_case(Process(),{10:row(rss=media.ASSET_RSS+1)})
        self.assertEqual(code,1);stop.assert_called_once()

    def test_output_limit_applies_even_when_child_exits_before_first_sample(self):
        log=io.BytesIO();log.seek(media.ASSET_OUTPUT+1)
        code,_,stop=self.run_case(Process(0),log=log)
        self.assertEqual(code,1);stop.assert_called_once()

    def test_forced_cleanup_of_leftover_children_cannot_report_success(self):
        with patch.object(media.subprocess,'Popen',return_value=Process(0)),\
             patch.object(media,'stop_renderer',return_value=(True,True)),\
             patch.object(media,'process_memory',return_value={}),patch.object(media.time,'monotonic',return_value=1):
            self.assertEqual(media.run_renderer(['swift'],Path('/workspace'),io.BytesIO(),[],100),125)

    def test_real_nonzero_exit_is_preserved(self):
        code,_,_=self.run_case(Process(7));self.assertEqual(code,7)

    def test_cleanup_failure_cannot_turn_into_success(self):
        code,_,_=self.run_case(Process(0),cleanup=False);self.assertEqual(code,125)

    def test_interrupt_also_runs_bounded_cleanup(self):
        code,_,stop=self.run_case(Process(),poll_error=KeyboardInterrupt())
        self.assertEqual(code,130);stop.assert_called_once()

    def test_launch_failure_does_not_invent_a_child_or_cleanup_hold(self):
        with patch.object(media.subprocess,'Popen',side_effect=OSError('launch failed')),\
             patch.object(media,'stop_renderer') as stop,patch.object(media.time,'monotonic',return_value=1),patch('sys.stderr',io.StringIO()):
            self.assertEqual(media.run_renderer(['swift'],Path('/workspace'),io.BytesIO(),[],10),1)
        stop.assert_not_called()


class OwnershipTests(unittest.TestCase):
    def test_new_child_need_not_exist_in_earlier_snapshot_and_reparenting_retains_identity(self):
        known={10:'original'}
        self.assertEqual(media.owned_processes(10,known,{10:row()},True),{10})
        self.assertEqual(media.owned_processes(10,known,{10:row(),20:row(parent=10)},True),{10,20})
        self.assertEqual(media.owned_processes(10,known,{20:row(parent=1)},False),{20})
        self.assertEqual(media.owned_processes(10,known,{20:row(parent=999,start='reused')},False),set())

    def test_sampler_uses_metadata_only_and_parses_kernel_start_and_rss(self):
        text=b'10 1 10 Wed Oct 28 23:56:58 2026 256\n'
        with patch.object(media.subprocess,'check_output',return_value=text) as query:
            rows=media.process_memory()
        self.assertEqual(rows[10]['rss'],256*1024)
        self.assertNotIn('command',query.call_args.args[0][-1])
        self.assertNotIn('args',query.call_args.args[0][-1])
        self.assertEqual(query.call_args.kwargs['timeout'],1)


class CleanupTests(unittest.TestCase):
    def test_term_then_kill_and_reap_stay_bounded(self):
        process=Process();now=[0.0];killed=[False]
        def sleep(seconds):now[0]+=seconds
        def group(pid,signum):
            if signum==media.signal.SIGKILL:killed[0]=True
        def wait(timeout):
            self.assertGreater(timeout,0);self.assertLessEqual(timeout,.1)
            process.waits.append(timeout);now[0]+=min(timeout,.1)
            if killed[0]:process.returncode=-9;return -9
            raise subprocess.TimeoutExpired('owned renderer',timeout)
        process.wait=wait
        def memory(timeout=1):return {} if killed[0] else {10:row()}
        with patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=sleep),\
             patch.object(media,'process_memory',side_effect=memory),\
             patch.object(media.os,'killpg',side_effect=group) as groups,patch.object(media.os,'kill'):
            self.assertEqual(media.stop_renderer(process,{10:'original'},4),(True,True))
        self.assertEqual([call.args[1] for call in groups.call_args_list],[media.signal.SIGTERM,media.signal.SIGKILL])
        self.assertEqual(process.returncode,-9);self.assertLessEqual(now[0],4)

    def test_reused_pid_is_not_signalled(self):
        process=Process(0)
        with patch.object(media,'process_memory',return_value={20:row(parent=999,start='reused',group=999)}),\
             patch.object(media.os,'kill') as kill,patch.object(media.os,'killpg') as group,\
             patch.object(media.time,'monotonic',return_value=0):
            self.assertEqual(media.stop_renderer(process,{20:'original'},4),(True,False))
        kill.assert_not_called();group.assert_not_called()

    def test_permanent_metadata_error_reaps_direct_child_and_returns_bounded_uncertainty(self):
        process=Process();now=[0.0]
        def wait(timeout):process.returncode=-15;return -15
        process.wait=wait
        with patch.object(media,'process_memory',side_effect=OSError('metadata unavailable')),\
             patch.object(media.os,'killpg') as group,patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=lambda seconds:now.__setitem__(0,now[0]+seconds)),\
             patch('sys.stderr',io.StringIO()):
            self.assertEqual(media.stop_renderer(process,{},4),(False,True))
        self.assertEqual(process.returncode,-15);self.assertLessEqual(now[0],4.01)
        group.assert_called_once_with(10,media.signal.SIGTERM)


class PublicationTests(unittest.TestCase):
    def test_failed_renderer_leaves_manifest_and_reference_publication_untouched(self):
        with tempfile.TemporaryDirectory() as temp:
            directory=Path(temp);manifest=directory/'manifest.json';manifest.write_text('{"old":"unchanged"}')
            with patch.object(media,'MEDIA',directory),patch.object(media.sys,'argv',['ship-reference.py']),\
                 patch.object(media.ship_files,'read_ships',return_value=[{'id':'SH001'}]),\
                 patch.object(media,'shared_hash',return_value='new'),patch.object(media,'needs_render',return_value=True),\
                 patch.object(media,'render_media',side_effect=RuntimeError('renderer failed')),patch.object(media,'references') as refs:
                with self.assertRaisesRegex(RuntimeError,'renderer failed'):media.main()
            self.assertEqual(manifest.read_text(),'{"old":"unchanged"}');refs.assert_not_called()




class EntryPointTests(unittest.TestCase):
    def setup_entry(self,root,guard=None):
        @contextmanager
        def claim(path):yield SimpleNamespace(fileno=lambda:3)
        custody=root/'native/diagnostic-custody'
        if guard is not None:custody.mkdir(parents=True)
        return {'recoverable_shards':SimpleNamespace(file_claim=claim,worker_limit=worker_limit),
                'native_runner':SimpleNamespace(diagnostic_custody_root=lambda:custody,
                    require_diagnostic_custody_clear=guard or (lambda:None))}

    def test_insufficient_ram_refuses_before_renderer_or_asset_directory(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with patch.dict(sys.modules,self.setup_entry(root)),patch.object(media.Path,'cwd',return_value=root),\
                 patch.object(media.subprocess,'check_output',return_value=b'page size of 16384 bytes\nPages free: 1.\nPages inactive: 1.\nPages speculative: 1.'),\
                 patch.object(media,'run_renderer') as run:
                with self.assertRaisesRegex(ValueError,'RAM'):media.render_media(['SH001'])
            run.assert_not_called();self.assertFalse((root/'.build').exists())

    def test_historical_hold_is_still_respected_before_any_probe(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            def hold():raise ValueError('historical hold')
            with patch.dict(sys.modules,self.setup_entry(root,hold)),patch.object(media.Path,'cwd',return_value=root),\
                 patch.object(media.subprocess,'check_output') as query,patch.object(media,'run_renderer') as run:
                with self.assertRaisesRegex(ValueError,'historical hold'):media.render_media(['SH001'])
            query.assert_not_called();run.assert_not_called()

    def test_standard_entry_uses_single_worker_actual_renderer_and_no_custom_session(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            with patch.dict(sys.modules,self.setup_entry(root)),patch.object(media.Path,'cwd',return_value=root),\
                 patch.object(media.subprocess,'check_output',return_value=b'page size of 16384 bytes\nPages free: 1000000.\nPages inactive: 1000000.\nPages speculative: 1000000.'),\
                 patch.object(media.shutil,'disk_usage',return_value=SimpleNamespace(free=200*1024**3)),\
                 patch.object(media,'run_renderer',return_value=0) as run:
                media.render_media(['SH001'])
            self.assertEqual(run.call_args.args[0],['swift','run','--jobs','1','-Xswiftc','-disable-batch-mode','Elite','--ship-media','SH001'])
            self.assertEqual(len(list((root/'.build').glob('ship-media-*/render.log'))),1)
            self.assertEqual(list(root.rglob('policy.json')),[]);self.assertEqual(list(root.rglob('state.json')),[])




class CancellationCorrectionTests(unittest.TestCase):
    def run_cancel(self,phase):
        process=Process();active={};changes=[];trace=[]
        previous={media.signal.SIGINT:media.signal.default_int_handler,media.signal.SIGTERM:media.signal.SIG_DFL}
        def handler(signum,value):active[signum]=value;changes.append((signum,value))
        def spawn(*args,**kwargs):
            if phase=='startup':active[media.signal.SIGTERM](media.signal.SIGTERM,None)
            return process
        def poll():
            if phase=='running':active[media.signal.SIGTERM](media.signal.SIGTERM,None);return None
            process.returncode=0;return 0
        process.poll=poll
        def cleanup(*args):
            trace.append('cleanup-start')
            for signum in (media.signal.SIGTERM,media.signal.SIGINT,media.signal.SIGTERM):active[signum](signum,None)
            trace.append('cleanup-finished')
            return True,False
        with patch.object(media.signal,'getsignal',side_effect=lambda signum:previous[signum]),\
             patch.object(media.signal,'signal',side_effect=handler),patch.object(media.subprocess,'Popen',side_effect=spawn),\
             patch.object(media,'process_memory',return_value={}),patch.object(media,'stop_renderer',side_effect=cleanup),\
             patch.object(media.time,'monotonic',return_value=1),patch.object(media.time,'sleep'):
            code=media.run_renderer(['swift'],Path('/workspace'),io.BytesIO(),[],100)
        self.assertEqual(code,128+media.signal.SIGTERM)
        self.assertEqual(trace,['cleanup-start','cleanup-finished'])
        self.assertEqual(dict(changes[-2:]),previous)

    def test_sigterm_during_running_and_repeated_cleanup_cancellation_restore_handlers(self):self.run_cancel('running')
    def test_sigterm_during_child_startup_still_reaches_cleanup(self):self.run_cancel('startup')
    def test_first_sigterm_during_cleanup_cannot_interrupt_or_report_success(self):self.run_cancel('cleanup')

    def test_expired_budget_refuses_before_spawning(self):
        with patch.object(media.time,'monotonic',return_value=9),patch.object(media.subprocess,'Popen') as spawn,\
             patch.object(media,'stop_renderer') as stop,patch('sys.stderr',io.StringIO()):
            self.assertEqual(media.run_renderer(['swift'],Path('/workspace'),io.BytesIO(),[],10),124)
        spawn.assert_not_called();stop.assert_not_called()


class GroupSurvivorCorrectionTests(unittest.TestCase):
    def test_unbound_same_group_survivor_after_leader_reap_blocks_success_without_pid_only_signal(self):
        process=Process(0);now=[0.0]
        with patch.object(media,'process_memory',return_value={20:row(parent=1,group=10)}),\
             patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=lambda seconds:now.__setitem__(0,now[0]+seconds)),\
             patch.object(media.os,'kill') as kill,patch.object(media.os,'killpg') as group,patch('sys.stderr',io.StringIO()):
            self.assertEqual(media.stop_renderer(process,{},4),(False,False))
        kill.assert_not_called();group.assert_not_called();self.assertLessEqual(now[0],4.01)

    def test_first_sample_before_poll_discovers_reparented_ordinary_follower(self):
        process=Process();now=[0.0];alive=[True]
        def poll():process.returncode=0;return 0
        process.poll=poll
        def memory(timeout=1):return {20:row(parent=1,group=10)} if alive[0] else {}
        def kill(pid,signum):
            self.assertEqual(pid,20);alive[0]=False
        with patch.object(media.subprocess,'Popen',return_value=process),patch.object(media,'process_memory',side_effect=memory),\
             patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=lambda seconds:now.__setitem__(0,now[0]+seconds)),\
             patch.object(media.os,'kill',side_effect=kill) as signals,patch.object(media.os,'killpg') as groups:
            code=media.run_renderer(['swift'],Path('/workspace'),io.BytesIO(),[],100)
        self.assertEqual(code,125);self.assertFalse(alive[0]);signals.assert_called();groups.assert_not_called()

    def test_follower_appearing_during_leader_wait_is_checked_after_reap(self):
        process=Process();now=[0.0];late=[False]
        def wait(timeout):process.returncode=-15;late[0]=True;return -15
        process.wait=wait
        def memory(timeout=1):return {20:row(parent=1,group=10)} if late[0] else {10:row()}
        with patch.object(media,'process_memory',side_effect=memory),patch.object(media.os,'killpg'),\
             patch.object(media.os,'kill') as kill,patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=lambda seconds:now.__setitem__(0,now[0]+seconds)),\
             patch('sys.stderr',io.StringIO()):
            self.assertEqual(media.stop_renderer(process,{},4),(False,True))
        self.assertNotIn(20,[call.args[0] for call in kill.call_args_list])

    def test_term_ends_leader_but_known_reparented_follower_still_receives_kill(self):
        process=Process();now=[0.0];leader_dead=[False];follower_dead=[False]
        def group(pid,signum):
            self.assertEqual(signum,media.signal.SIGTERM);leader_dead[0]=True
        def kill(pid,signum):
            if pid==20 and signum==media.signal.SIGKILL:follower_dead[0]=True
        def wait(timeout):
            if leader_dead[0]:process.returncode=-15;return -15
            raise subprocess.TimeoutExpired('owned renderer',timeout)
        process.wait=wait
        def memory(timeout=1):
            rows={}
            if not leader_dead[0]:rows[10]=row()
            if not follower_dead[0]:rows[20]=row(parent=1 if leader_dead[0] else 10)
            return rows
        with patch.object(media,'process_memory',side_effect=memory),patch.object(media.os,'killpg',side_effect=group) as groups,\
             patch.object(media.os,'kill',side_effect=kill) as signals,\
             patch.object(media.time,'monotonic',side_effect=lambda:now[0]),\
             patch.object(media.time,'sleep',side_effect=lambda seconds:now.__setitem__(0,now[0]+seconds)):
            self.assertEqual(media.stop_renderer(process,{},4),(True,True))
        self.assertTrue(follower_dead[0]);groups.assert_called_once_with(10,media.signal.SIGTERM)
        self.assertIn((20,media.signal.SIGKILL),[call.args for call in signals.call_args_list])
        self.assertLessEqual(now[0],4)


if __name__=='__main__':unittest.main()
