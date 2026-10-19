import io
import json
import unittest
import urllib.error
from email.message import Message

import check_readme_downloads as TOOL


URL = "https://github.com/stephenlclarke/elite/releases/download/v1.4.0/Elite-1.4.0-universal.zip"


class Response:
    def __init__(self, status=200, body=b"large body"):
        self.status, self.body, self.reads, self.closed = status, body, [], False

    def read(self, count):
        self.reads.append(count)
        return self.body[:count]

    def close(self):
        self.closed = True


class Opener:
    def __init__(self, responses):
        self.responses, self.requests = list(responses), []

    def open(self, request, timeout):
        self.requests.append(request)
        result = self.responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return result


class ReadmeDownloadsTests(unittest.TestCase):
    def test_indented_examples_not_probed_and_nested_list_prose_is_probed(self):
        base = 'https://github.com/stephenlclarke/elite/releases/tag/'
        text = f'''    [four spaces]({base}v9.0.0)

        [continued code]({base}v9.0.1)

\t[tab code]({base}v9.0.2)

- Download:
    [real nested paragraph]({base}v1.4.0)

      [list indented code]({base}v9.0.3)

  - Nested item:
      [real child paragraph]({base}v1.3.1)

-     [code on list marker]({base}v9.0.4)

An ordinary paragraph
    [lazy paragraph continuation]({base}v1.2.0)
'''
        calls = []
        def requester(url, **kwargs):
            calls.append(url)
            return {'httpStatus': 404 if '/v9.' in url else 200, 'finalURL': url, 'body': b''}
        result = TOOL.check(text, 'stephenlclarke/elite', requester=requester)
        self.assertEqual(result['state'], 'REACHABLE')
        self.assertEqual(set(calls), {base+'v1.4.0', base+'v1.3.1', base+'v1.2.0'})
        self.assertFalse(any('/v9.' in url for url in calls))

    def test_real_links_not_code_comments_or_badges(self):
        text = f'''[Old archive]({URL})
<a href="https://github.com/stephenlclarke/elite/releases/latest">Latest release</a>
[Current][release]
[release]: https://github.com/stephenlclarke/elite/releases/tag/v1.4.0
`[not a link]({URL.replace('1.4.0','9.9.9')})`
```
[example]({URL.replace('1.4.0','8.8.8')})
```
<!-- [hidden]({URL.replace('1.4.0','7.7.7')}) -->
![badge](https://img.shields.io/github/v/release/stephenlclarke/elite)
'''
        found = TOOL.links(text, "stephenlclarke/elite")
        self.assertEqual(len(found), 3)
        self.assertEqual(next(r for r in found if r['url'] == URL)['asset'], 'Elite-1.4.0-universal.zip')

    def test_head_has_no_body_and_range_fallback_reads_one_byte(self):
        head, ranged = Response(), Response(206, b"abc" * 100)
        result = TOOL.request(URL, opener=Opener([head]))
        self.assertEqual(result['body'], b'')
        self.assertEqual(head.reads, [])
        self.assertTrue(head.closed)
        result = TOOL.request(URL, method='GET', one_byte=True, opener=Opener([ranged]))
        self.assertEqual(result['body'], b'a')
        self.assertEqual(ranged.reads, [1])
        calls = []
        def requester(url, **kwargs):
            calls.append(kwargs)
            return {'httpStatus': 405 if not kwargs else 206, 'finalURL': url, 'body': b'x' if kwargs else b''}
        report = TOOL.probe(URL, requester)
        self.assertEqual(report['state'], 'reachable')
        self.assertEqual(calls, [{}, {'method': 'GET', 'one_byte': True}])

    def test_unofficial_redirect_refused_without_consuming_redirect_body(self):
        headers = Message()
        headers['Location'] = 'https://attacker.invalid/large.zip'
        body = io.BytesIO(b'never read')
        error = urllib.error.HTTPError(URL, 302, 'redirect', headers, body)
        opener = Opener([error])
        with self.assertRaises(ValueError):
            TOOL.request(URL, opener=opener)
        self.assertEqual(len(opener.requests), 1)
        self.assertTrue(body.closed)
        for url in ('http://github.com/file', 'https://github.com.attacker.invalid/file', 'https://user:secret@github.com/file'):
            with self.assertRaises(ValueError):
                TOOL.official(url)
        credentialled = URL.replace('https://', 'https://user:secret@') + '?token=secret'
        report = TOOL.check(f'[unsafe]({credentialled})', 'stephenlclarke/elite')
        self.assertNotIn('secret', json.dumps(report))
        self.assertEqual(report['links'][0]['state'], 'inconclusive')

    def test_historical_broken_and_inconclusive_are_distinct(self):
        def requester(url, **kwargs):
            if 'api.github.com' in url:
                body = json.dumps({'tag_name': 'v1.5.0', 'assets': [{'name': 'Elite-1.5.0-universal.zip'}]}).encode()
                return {'httpStatus': 200, 'finalURL': url, 'body': body}
            status = 404 if '1.2.0' in url else 429 if '1.3.0' in url else 200
            return {'httpStatus': status, 'finalURL': url, 'body': b''}
        old = TOOL.check(f'[Historical]({URL})', 'stephenlclarke/elite', '1.4.0', True, requester)
        self.assertEqual(old['state'], 'REACHABLE')
        self.assertEqual(old['links'][0]['versionRelationship'], 'historical_or_different')
        self.assertTrue(old['expectedVersionDiffersFromPublicMetadata'])
        self.assertEqual(old['expectedAssetURLFromExistingCaskHelper'], URL)
        broken = TOOL.probe(URL.replace('1.4.0', '1.2.0'), requester)
        limited = TOOL.probe(URL.replace('1.4.0', '1.3.0'), requester)
        self.assertEqual((broken['state'], limited['state']), ('broken', 'inconclusive'))

    def test_budget_and_network_failures_are_bounded(self):
        content = '\n'.join(f'[release](https://github.com/stephenlclarke/elite/releases/tag/v1.0.{i})' for i in range(13))
        with self.assertRaises(ValueError):
            TOOL.links(content, 'stephenlclarke/elite')
        def failed(url, **kwargs):
            raise urllib.error.URLError('offline')
        self.assertEqual(TOOL.probe(URL, failed)['state'], 'inconclusive')
        self.assertEqual(TOOL.latest('stephenlclarke/elite', failed)['state'], 'inconclusive')


if __name__ == '__main__':
    unittest.main()
