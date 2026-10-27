import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location("markets", Path(__file__).resolve().parents[1] / "prepare-original-markets.py")
TOOL = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TOOL)


def toml(value):
    if isinstance(value, dict):
        return '{' + ','.join(json.dumps(k) + '=' + toml(v) for k, v in value.items()) + '}'
    if isinstance(value, list):
        return '[' + ','.join(toml(v) for v in value) + ']'
    return json.dumps(value)


class OriginalMarketTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.source = self.root / 'inputs/original-world-economy'
        self.source.mkdir(parents=True)
        self.config = {'version': TOOL.VERSION, 'systemsPerGalaxy': 1, 'galaxies': [{}], 'commodities': [{'index': 0, 'name': 'Original food', 'unit': 't'}, {'index': 1, 'name': 'Original metal', 'unit': 'kg'}]}
        self.catalogue = {'version': TOOL.VERSION, 'systems': [{'key': 'G01-S000', 'galaxy': 0, 'system': 0, 'worldVersion': TOOL.VERSION}]}
        self.rows = [{'system': 0, 'index': i, 'name': c['name'], 'unit': c['unit'], 'askTenthsCR': 73+i, 'bidTenthsCR': 61+i, 'stock': i, 'targetStock': 18+i, 'epoch': 7, 'worldVersion': TOOL.VERSION} for i,c in enumerate(self.config['commodities'])]
        self.write()

    def write(self):
        (self.source/'authoring.toml').write_text('\n'.join(k+'='+toml(v) for k,v in self.config.items()))
        (self.source/'catalogue.json').write_text(json.dumps(self.catalogue))
        (self.source/'markets-01.toml').write_text('version='+toml(TOOL.VERSION)+'\nstatus="Historical source provenance"\nmarkets='+toml(self.rows))
        entries=[]
        for f in sorted(self.source.iterdir()):
            raw=f.read_bytes();entries.append({'path':f.relative_to(self.root).as_posix(),'bytes':len(raw),'sha256':TOOL.sha(raw),'approvedInventoryPath':'approved/'+f.name})
        self.manifest=self.root/'input-manifest.json'
        self.manifest.write_text(json.dumps({'sourceCommit':'a'*40,'inputs':entries}))

    def prepare(self, name='output'):
        return TOOL.prepare(self.manifest,self.root/name,galaxies=1,systems=1,commodity_count=2)

    def test_exact_values_and_determinism(self):
        a=self.prepare('a');b=self.prepare('b');self.assertEqual(a,b)
        raw=(self.root/'a/markets.json').read_bytes();self.assertEqual(raw,(self.root/'b/markets.json').read_bytes())
        self.assertEqual(json.loads(raw)['markets'][0]['quotes'],self.rows)
        self.assertEqual(a['quoteCount'],2);self.assertEqual(a['sourceDescriptiveStatuses']['markets-01.toml'],'Historical source provenance')

    def test_duplicate_missing_foreign_and_schema_refused(self):
        original=copy.deepcopy(self.rows)
        for mutation in ('duplicate','missing','foreign','extra','name','version'):
            with self.subTest(mutation=mutation):
                self.rows=copy.deepcopy(original)
                if mutation=='duplicate':self.rows.append(self.rows[0])
                elif mutation=='missing':self.rows.pop()
                elif mutation=='foreign':self.rows[0]['system']=1
                elif mutation=='extra':self.rows[0]['invented']=1
                elif mutation=='name':self.rows[0]['name']='foreign'
                else:self.rows[0]['worldVersion']='foreign'
                self.write()
                with self.assertRaises(ValueError):self.prepare(mutation)
                self.assertFalse((self.root/mutation).exists())

    def test_integer_bool_float_negative_and_spread_refused(self):
        for value in (True,1.0,-1,2**63):
            self.rows[0]['stock']=value;self.write()
            with self.assertRaises(ValueError):self.prepare(str(value))
        self.rows[0]['stock']=0;self.rows[0]['bidTenthsCR']=1000;self.write()
        with self.assertRaises(ValueError):self.prepare('crossed')

    def test_authentication_paths_symlink_overlap_and_bounds(self):
        (self.source/'markets-01.toml').write_text('altered')
        with self.assertRaisesRegex(ValueError,'fingerprint'):self.prepare()
        self.write()
        manifest=json.loads(self.manifest.read_text());manifest['inputs'][0]['path']='../unsafe';self.manifest.write_text(json.dumps(manifest))
        with self.assertRaises(ValueError):self.prepare('unsafe')
        self.write();empty=self.root/'empty';empty.mkdir();link=self.root/'link';link.symlink_to(empty,target_is_directory=True)
        with self.assertRaises(ValueError):TOOL.prepare(self.manifest,link,1,1,2)
        self.assertEqual(list(empty.iterdir()),[])
        with self.assertRaises(ValueError):TOOL.prepare(self.manifest,self.source/'nested',1,1,2)
        sample=self.root/'large';sample.write_bytes(b'x'*20)
        with self.assertRaises(ValueError):TOOL.read(sample,10)


if __name__=='__main__':unittest.main()
