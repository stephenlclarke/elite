#!/usr/bin/env python3
"""Incremental renderer GIFs and Markdown from the exact runtime ship TOMLs."""
import argparse
import hashlib
import importlib.util
import json
import os
import shutil
import signal
import sys
import tempfile
import time
from contextlib import ExitStack
import re
from pathlib import Path
import subprocess

_spec=importlib.util.spec_from_file_location('ship_files',Path(__file__).with_name('ship-files.py'))
ship_files=importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ship_files)
MEDIA=Path('docs/ships')
SETTINGS=b'right-on-ship-gif-v1:256-square:24-frames:0.1s:cyan-shaded:camera400:focal340'
LABELS={'cargo':'Cargo (t)','speed':'Top speed','acceleration':'Acceleration (speed/s)','energy':'Energy capacity','recharge':'Energy recharge /s','roll':'Roll (rad/s)','pitch':'Pitch (rad/s)','yaw':'Yaw (rad/s)','shield':'Each shield','shieldRecharge':'Shield recharge /s','fuel':'Fuel tank (LY)','jump':'Base jump (LY)','spool':'Jump charge (s)','missiles':'Missile pylons','facings':'Laser mounts','cargoExpansion':'Cargo bay upgrade (t)','price':'Hull price (CR)'}


def digest(data):
    """Use content identity rather than path or modification time."""
    return hashlib.sha256(data).hexdigest()


# exportShipMedia -> Display.shipPortrait -> CatalogueShip.previewMesh / Display.draw
# -> imageFor / drawFrame (Quartz CPU path; no ShipPanelRenderer is supplied).
# Keep this boundary in sync when that call path gains a dependency. See docs/PR-75.md.
RENDER_FILES = (
    'Package.swift', 'Package.resolved',
    'Sources/EliteCore/AutoTargetControl.swift',  # Basis3 and SpaceBody.modelVector
    'Sources/EliteCore/CockpitDisplay.swift',  # Frame.label
    'Sources/EliteCore/Display.swift',  # palette, bitmap font, frame and Display.draw
    'Sources/EliteCore/Geometry.swift',
    'Sources/EliteCore/Graphics.swift',
    'Sources/EliteCore/OriginalShipTextureAssets.swift',
    'Sources/EliteCore/ShipAppearance.swift',
    'Sources/EliteCore/ShipCatalogue.swift',
    'Sources/EliteCore/ShipCatalogueMetadata.swift',
    'Sources/EliteCore/ShipPerformance.swift',
    'Sources/EliteCore/ShipPortrait.swift',
    'Sources/EliteCore/ShipRendering.swift',
    'Sources/EliteCore/ShipTextureAssets.swift',
    'Sources/EliteCore/ShipTextureRaster.swift',
    'Sources/EliteCore/ShowroomGeometry.swift',
    'Sources/EliteCore/ScriptNPCRendering.swift',  # Display.draw's beam guard
    'Sources/EliteMac/NativeGraphics.swift',
    'Sources/EliteMac/ShipMedia.swift',
)
TEXTURE_FOLDERS = (
    'Sources/EliteCore/Resources/ShipTextures',
    'Sources/EliteCore/Resources/OriginalShipTextures',
)
# The portrait explicitly sets .front and .shadedPanels and supplies its own mesh.
# Only this view transform is read from Game.swift by that fixed drawing path.
# Missing, renamed, duplicate or reversed declaration boundaries fail closed.
VIEW_START = '  public func viewPosition(_ p: Vector3) -> Vector3 {\n'
VIEW_END = '  private mutating func moveBodies(dt: Double) {\n'


def view_transform(root):
    """Read the renderer's Game transform without hashing unrelated simulation methods."""
    text = (root/'Sources/EliteCore/Game.swift').read_text()
    if text.count(VIEW_START) != 1 or text.count(VIEW_END) != 1:
        raise ValueError('Update ship media view-transform dependency boundaries')
    start = text.index(VIEW_START)
    end = text.index(VIEW_END)
    if end <= start:
        raise ValueError('Invalid ship media view-transform dependency boundaries')
    return text[start:end].encode()


def shared_hash(root=Path('.')):
    """Hash the maintained portrait path, settings and both authenticated texture trees."""
    paths = [root/name for name in RENDER_FILES]
    for folder in TEXTURE_FOLDERS:
        textures = root/folder
        if textures.is_dir():
            paths.extend(path for path in textures.rglob('*') if path.is_file())
    h = hashlib.sha256(b'ship-media-render-dependencies-v2')

    def add(name, data):
        # Framing prevents a file boundary/name change from aliasing concatenated bytes.
        name = name.encode()
        h.update(len(name).to_bytes(8, 'big'))
        h.update(name)
        h.update(len(data).to_bytes(8, 'big'))
        h.update(data)

    add('settings', SETTINGS)
    add('Sources/EliteCore/Game.swift#viewPosition', view_transform(root))
    for path in sorted(paths):
        add(path.relative_to(root).as_posix(), path.read_bytes())
    return h.hexdigest()


def fingerprint(spec_bytes, shared):
    """An individual specification or embedded design edit invalidates that GIF."""
    return digest(spec_bytes+shared.encode())


def needs_render(path, shared, previous, gif):
    """Also detect missing or tampered generated media."""
    return (previous.get('input') != fingerprint(path.read_bytes(),shared)
            or not gif.is_file() or previous.get('output') != digest(gif.read_bytes()))


def escape(text):
    """Keep source facts inside portable Markdown table cells."""
    escaped = str(text).replace('|','\\|').replace('\n',' ').strip() or '(empty)'
    return re.sub(r'(?<![<(])https?://[^\s<>]*[^\s<>.,;)]', r'<\g<0>>', escaped)


def spec_text(key, number):
    """Use player units and ordinary decimals, not source bitmasks/scientific notation."""
    if key=='fuel':return format(number/10,'.1f')
    if key=='facings':return ', '.join(name for bit,name in [(1,'Front'),(2,'Rear'),(4,'Left'),(8,'Right')] if number & bit)
    if key in {'cargo','cargoExpansion','missiles','price'}:return format(number,',.0f')
    return format(number,'.1f')


def references(ships, write=True):
    """Generate tables from authoritative gameplay values, with source detail separate."""
    balances = ship_files.catalogue_balance.load_balances()
    for ship in ships:
        ship_files.catalogue_balance.require_consistent(ship, balances)
    lines=['# Ship catalogue','', 'Generated by `make ships` from [the authoritative TOML folder](../Sources/EliteCore/Resources/Ships). Each animation uses the actual game renderer and embedded design. Do not edit this document or GIFs by hand.','',
           'All values below are standard hull values. Carried equipment modifies them in the game. Top speed uses the cockpit scale (32 for Cobra Mk III); world travel is speed x 18 units/second. Shields and energy are native game pools. See [conversions, fitting and economics](SHIP-FILES.md) and [source/design provenance](SHIP-PROVENANCE.md).','',
           'Exchange at a main station: new hull price less 75% of your current hull price. Compatible equipment, cargo, fuel and mission property transfer unchanged; conflicts block the trade. There are no free missiles, lasers or fuel. Normal fabrication requires an exact-hull blueprint from an actual credited kill and registration by that system AI at a qualified genuine dock. Targeting alone grants no purchase. Catalogue capability is separate from commander knowledge. XYZZY-only hulls are excluded from normal purchase and discovery; pending native mechanics are labelled explicitly.','']
    provenance=['# Ship source and design provenance','', '<!-- markdownlint-disable MD024 MD033 -->', '', 'Generated from the same TOMLs as the game. Original designs are interpretations, not historical or authentic source geometry. MIT covers project-authored geometry; imported designs retain their listed terms and [original notices](../NOTICE.md). Dimensions may be estimates and are not SI docking-clearance measurements.','']
    for ship in ships:
        identity=ship['id'];design=ship['design'];game=ship.get('game')
        lines += ['## '+identity+' - '+ship['name'],'', '![Rotating '+ship['name']+'](ships/'+identity+'.gif)','',
                  '**Class:** '+ship['shipClass']+' | [Definition](../Sources/EliteCore/Resources/Ships/'+identity+'.toml) | [Provenance](SHIP-PROVENANCE.md#'+identity.lower()+')','', '| Game specification | Value |','| --- | --- |']
        metadata=ship['catalogue']
        primary=metadata.get('primaryType')
        role_label='Bounty hunter' if primary=='bountyHunter' else (primary or 'None').capitalize()
        lines += ['| Project family | '+escape(metadata['family'])+' |',
                  '| Primary display type | '+escape(role_label)+' |',
                  '| Functional AI role | '+escape(metadata.get('primaryRole') or 'None')+' |',
                  '| Object kind / origin | '+escape(metadata['objectKind']+' / '+metadata['origin'])+' |',
                  '| Capital parent / subtype | '+('Yes / '+escape(metadata['capitalSubtype']) if metadata['isCapital'] else 'No')+' |',
                  '| Catalogue discovery eligibility | '+('Yes' if metadata['discoveryEligible'] else 'No')+' |',
                  '| Encounter provision | '+escape(metadata['encounterMode']+'; mechanics '+metadata['mechanicsStatus'])+' |',
                  '| Rarity | '+escape(metadata['rarity'])+' |',
                  '| Player flyable | '+('Yes' if metadata['playerFlyable'] else 'No')+' |',
                  '| Normal purchase capability | '+('Yes' if metadata['normalPurchaseEligible'] else 'No')+' |',
                  '| Purchase policy | '+escape(metadata['purchasePolicy'])+' |',
                  '| Minimum displayed build Tech Level | '+str(metadata.get('minimumBuildTechLevel', 'Not applicable'))+' |',
                  '| Collection milestone | '+escape(metadata['collectionMilestone'])+' |',
                  '| Damage policy | '+escape(metadata['damagePolicy'])+' |']
        if metadata.get('habitat'):
            habitat=metadata['habitat']
            lines += ['| Natural habitat | Government '+escape(','.join(str(g) for g in habitat['governments']))+'; displayed Tech Level '+str(habitat['minimumDisplayedTechLevel'])+'+; independent of fabrication |']
        if game:
            lines += ['| '+label+' | '+spec_text(key,game[key])+' |' for key,label in LABELS.items()]
            power=game['energy']+2*game['shield']+32*game['recharge']+64*game['missiles']+128*game['facings'].bit_count()
            lines += ['| Power index | '+format(power,'.1f')+' |','| Trade-in (CR) | '+format(game['price']*.75,'.1f')+' |']
        else:lines += ['| Native gameplay profile | '+escape(metadata['mechanicsStatus'])+'; no player performance profile |']
        lines += ['| Design | '+str(len(design['vertices']))+' vertices; '+str(len(design['faces']))+' faces |','']
        provenance += ['<a id="'+identity.lower()+'"></a>','', '## '+identity+' - '+ship['name'],'', '**Design:** '+design['source']+'; '+design['license']+'.','', ship['geometryContext'],'',
                       '**Appearances:** '+ship['appearances']+'; **evidence:** '+ship['evidence']+'.','']
        if 'recipe' in design:
            provenance += ['Original project interpretation: '+design['recipe']['family']+' family, individual sweep/components/envelope. Full authored geometry and recipe are embedded in the TOML. No gameplay statistic was inferred from the invented shape.','']
            if design['recipe']['family'] == 'liberator-dsv2':
                provenance += ['[Liberator visual references, palette and chosen native mechanics](LIBERATOR.md). Three radial nacelles, forward probes and an aft green engine; no external artwork or model asset is redistributed.','']
        else:provenance += ['Imported numerical geometry and complete custody metadata are embedded in the TOML; original source files/notices remain separately attributable. Six zero-area source triangles across three assemblies are harmless and skipped by back-face projection.','']
        if 'nativeHull' in ship:
            provenance += ['**Original encounter variant:** '+ship['nativeHull']+'. The game loads this retained variant from the same TOML; player adaptations above remain distinct.','']
            if 'nativeDesign' in ship:
                native=ship['nativeDesign']
                provenance += [native['source']+'; '+native['license']+'. '+str(len(native['vertices']))+' vertices, '+str(len(native['faces']))+' faces, '+str(len(native.get('details',[])))+' wire details. Original coordinate/face/detail digests are checked independently.','']
            if 'nativeCombat' in ship:
                provenance += ['| Original NPC field | Value |','| --- | --- |']
                provenance += ['| '+key+' | '+str(value)+' |' for key,value in ship['nativeCombat'].items()]
                provenance.append('')
        for profile in ship['profiles']:
            provenance += ['### '+profile['title'],'',profile['context'],'','| Field | Source value | Status / basis |','| --- | --- | --- |']
            provenance += ['| '+escape(f['label'])+' | '+escape(f['text'])+' | '+escape(f['status']+'; '+f['basis'])+' |' for f in profile['fields']]
            provenance.append('')
    documents = {'docs/SHIP-CATALOGUE.md':'\n'.join(lines),'docs/SHIP-PROVENANCE.md':'\n'.join(provenance)}
    if write:
        for path, text in documents.items():Path(path).write_text(text)
    return documents


# Local asset generation uses the same resource limits as the physical quality job,
# but not its diagnostic policies, immutable sessions or persistent custody records.
ASSET_RSS = 2415919104
ASSET_SECONDS = 7200
ASSET_CLEANUP = 4
ASSET_OUTPUT = 16 * 1024 * 1024


def process_memory(timeout=1):
    """Read kernel identity and RSS metadata only; argv text cannot reject an exec."""
    raw=subprocess.check_output(['/bin/ps','-axo','pid=,ppid=,pgid=,lstart=,rss='],
                                timeout=timeout,stderr=subprocess.PIPE).decode()
    rows={}
    for line in raw.splitlines():
        fields=line.split()
        if len(fields)!=9:raise RuntimeError('Incomplete process/RSS sample')
        pid,parent,group=map(int,fields[:3])
        rows[pid]={'parent':parent,'group':group,'start':' '.join(fields[3:8]),'rss':int(fields[8])*1024}
    return rows


def owned_processes(pid,known,rows,leader_unreaped):
    """Discover visible children and retain their kernel identities across exec/reparenting."""
    selected={key for key,start in known.items() if key in rows and rows[key]['start']==start}
    # Until Popen reaps its leader, that PID cannot be reused as a new group.
    if leader_unreaped:
        selected.update(key for key,row in rows.items() if row['group']==pid)
        if pid in rows and pid not in known:selected.add(pid)
    while True:
        added={key for key,row in rows.items() if row['parent'] in selected}-selected
        if not added:break
        selected.update(added)
    for key in selected:known[key]=rows[key]['start']
    return selected


def stop_renderer(process,known,deadline):
    """Bound cancellation/reaping; unbound surviving group members also block success."""
    signalled=False;unbound=[]
    def observe():
        rows=process_memory(min(1,max(.001,deadline-time.monotonic())))
        selected=owned_processes(process.pid,known,rows,process.returncode is None)
        group={pid for pid,row in rows.items() if row['group']==process.pid}
        return rows,selected,group-selected
    for signum in (signal.SIGTERM,signal.SIGKILL):
        if time.monotonic()>=deadline:break
        # Discover the original group before any wait/poll can reap its leader.
        try:rows,selected,unbound=observe()
        except Exception:selected=set()
        if process.returncode is None:
            try:os.killpg(process.pid,signum);signalled=True
            except ProcessLookupError:pass
            except OSError as error:print('Renderer session signal failed: '+type(error).__name__,file=sys.stderr)
        for pid in sorted(selected,key=lambda value:value==process.pid):
            if time.monotonic()>=deadline:break
            try:
                fresh=process_memory(min(1,deadline-time.monotonic())).get(pid)
                if fresh and fresh['start']==known[pid]:
                    try:os.kill(pid,signum);signalled=True
                    except ProcessLookupError:pass
            except Exception:pass
        end=min(deadline,time.monotonic()+2)
        while time.monotonic()<end:
            # Retain ordinary group followers before reaping a leader that TERM ended.
            if process.returncode is None:
                try:observe()
                except Exception:pass
            try:process.wait(timeout=min(.1,max(.001,end-time.monotonic())))
            except subprocess.TimeoutExpired:pass
            if time.monotonic()<deadline:
                try:
                    rows,remaining,unbound=observe()
                    if process.returncode is not None and not remaining and not unbound:return True,signalled
                except Exception:pass
            time.sleep(min(.05,max(0,end-time.monotonic())))
    if process.returncode is None:
        try:process.wait(timeout=0)
        except subprocess.TimeoutExpired:pass
    print('Renderer cleanup incomplete for leader '+str(process.pid)+'; unresolved group members '+str(sorted(unbound)),file=sys.stderr)
    return False,signalled


def run_renderer(command,root,log,descriptors,deadline):
    """Ordinary owned subprocess/session, sampled RSS and one bounded cleanup path."""
    process=None;known={};code=1;cancelled=[None];handlers={}
    def cancel(signum,frame):
        # Recording cancellation never raises inside startup or bounded cleanup.
        if cancelled[0] is None:cancelled[0]=signum
    try:
        for signum in (signal.SIGINT,signal.SIGTERM):
            previous=signal.getsignal(signum)
            signal.signal(signum,cancel);handlers[signum]=previous
        if time.monotonic()>=deadline-ASSET_CLEANUP:raise TimeoutError('Renderer deadline')
        if cancelled[0] is not None:return 128+cancelled[0]
        process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT,
            start_new_session=True,pass_fds=tuple(descriptors))
        while True:
            if cancelled[0] is not None:code=128+cancelled[0];break
            if time.monotonic()>=deadline-ASSET_CLEANUP:raise TimeoutError('Renderer deadline')
            if log.tell()>ASSET_OUTPUT:raise RuntimeError('Renderer output limit')
            rows=process_memory(min(1,max(.001,deadline-ASSET_CLEANUP-time.monotonic())))
            selected=owned_processes(process.pid,known,rows,process.returncode is None)
            selected.update(pid for pid,row in rows.items() if pid==os.getpid() or row['parent']==os.getpid())
            if sum(rows[pid]['rss'] for pid in selected)>ASSET_RSS:raise RuntimeError('Renderer RSS limit')
            # First observation precedes poll: even a short-lived leader reserves its group.
            if process.poll() is not None:code=process.returncode;break
            time.sleep(.1)
        if log.tell()>ASSET_OUTPUT:raise RuntimeError('Renderer output limit')
    except KeyboardInterrupt:
        code=130
    except Exception as error:
        print('Ship render failed: '+str(error),file=sys.stderr)
        code=124 if isinstance(error,TimeoutError) else 1
    finally:
        try:
            if process is not None:
                clean,signalled=stop_renderer(process,known,min(deadline,time.monotonic()+ASSET_CLEANUP))
                if not clean or (code==0 and signalled):code=125
        finally:
            for signum,previous in handlers.items():signal.signal(signum,previous)
    if cancelled[0] is not None and code==0:code=128+cancelled[0]
    return code


def render_media(ids):
    """Keep make ships as the sole asset route, with normal shared leases and no bespoke protocol."""
    root=Path.cwd()
    sys.path.insert(0,str(root/'Tools/CI'))
    from recoverable_shards import file_claim,worker_limit
    import native_runner
    controls=native_runner.diagnostic_custody_root().parent
    deadline=time.monotonic()+ASSET_SECONDS
    with ExitStack() as stack:
        locks=[stack.enter_context(file_claim(path)) for path in (
            controls/'recoverable-control.lock',controls/'sanitizer-checkpoints/executor.lock')]
        # Preserve any existing historical hold. Fresh developer Macs need no diagnostic bootstrap.
        if native_runner.diagnostic_custody_root().exists():native_runner.require_diagnostic_custody_clear()
        text=subprocess.check_output(['/usr/bin/vm_stat'],timeout=1,stderr=subprocess.PIPE).decode()
        page=re.search(r'page size of (\d+) bytes',text)
        counts=[re.search(re.escape(key)+r':\s*(\d+)\.',text) for key in ('Pages free','Pages inactive','Pages speculative')]
        if page is None or any(value is None for value in counts):raise RuntimeError('RAM admission sample unavailable')
        worker_limit(explicit=1,cpu_budget=min(1,os.cpu_count() or 0),
            ram_available=int(page[1])*sum(int(value[1]) for value in counts),ram_reserve=2147483648,
            peak_per_worker=ASSET_RSS,disk_available=shutil.disk_usage(root).free,
            disk_reserve=42949672960,disk_per_worker=85899345920)
        (root/'.build').mkdir(exist_ok=True)
        directory=Path(tempfile.mkdtemp(prefix='ship-media-',dir=root/'.build'))
        with (directory/'render.log').open('wb',buffering=0) as log:
            command=['swift','run','--jobs','1','-Xswiftc','-disable-batch-mode','Elite','--ship-media',*ids]
            code=run_renderer(command,root,log,[lock.fileno() for lock in locks],deadline)
        if code:raise RuntimeError('Ship renderer exited '+str(code)+'; log: '+str(directory/'render.log'))


def main():
    """Render changed ships first, then rebuild the central reference deterministically."""
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    args=parser.parse_args()
    ships=ship_files.read_ships();shared=shared_hash();manifest_path=MEDIA/'manifest.json'
    old=json.loads(manifest_path.read_text()) if manifest_path.exists() else {}
    changed=[s['id'] for s in ships if needs_render(ship_files.SHIP_FOLDER/(s['id']+'.toml'),shared,old.get(s['id'],{}),MEDIA/(s['id']+'.gif'))]
    if args.check:
        assert not changed,'Stale or missing GIFs: '+', '.join(changed)
        for path,text in references(ships,write=False).items():
            assert Path(path).read_text()==text,'Stale generated reference: '+path
        doc=Path('docs/SHIP-CATALOGUE.md').read_text()
        for ship in ships:
            assert doc.count('## '+ship['id']+' - ')==1
            assert '(ships/'+ship['id']+'.gif)' in doc
        print('All',len(ships),'TOMLs/GIFs/reference sections current');return
    if changed:render_media(changed)
    MEDIA.mkdir(parents=True,exist_ok=True)
    manifest={s['id']:dict(input=fingerprint((ship_files.SHIP_FOLDER/(s['id']+'.toml')).read_bytes(),shared),output=digest((MEDIA/(s['id']+'.gif')).read_bytes())) for s in ships}
    manifest_path.write_text(json.dumps(manifest,indent=2,sort_keys=True)+'\n')
    references(ships)
    print('Rendered',len(changed),'ships; reused',len(ships)-len(changed),'; reference:',len(ships),'ships')


if __name__=='__main__':main()
