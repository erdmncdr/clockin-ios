#!/usr/bin/env python3
"""Offline failure-path checks. All HTTP, credentials and process calls are mocked."""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch
import urllib.request

spec = importlib.util.spec_from_file_location('publisher', Path(__file__).with_name('publish-release.py'))
publisher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(publisher)


class PublisherTests(unittest.TestCase):
    def test_dry_run_has_no_io(self):
        with patch.object(publisher, 'http', side_effect=AssertionError('network')), \
             patch.object(publisher, 'github_token', side_effect=AssertionError('credential')), \
             patch.object(publisher, 'local_release', side_effect=AssertionError('files')), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            publisher.main(['2.0.0', '--dry-run'])
        self.assertIn('appcast.xml LAST', output.getvalue())
        self.assertIn('make_latest=false', output.getvalue())

    def test_yes_required_before_io(self):
        with patch.object(publisher, 'publish', side_effect=AssertionError('publish')):
            with self.assertRaisesRegex(RuntimeError, 'requires --yes'):
                publisher.main(['2.0.0'])

    def test_reject_version_path_injection(self):
        with self.assertRaisesRegex(RuntimeError, 'Version must'):
            publisher.main(['../../release', '--dry-run'])

    def test_token_never_redirected(self):
        request = urllib.request.Request('https://api.github.com/test', headers={'Authorization': 'Bearer test-only'})
        with self.assertRaisesRegex(RuntimeError, 'authenticated redirect'):
            publisher.NoAuthRedirect().redirect_request(request, None, 302, '', {}, 'https://example.com/')

    def test_token_host_restricted(self):
        with self.assertRaisesRegex(RuntimeError, 'another host'):
            publisher.http('GET', 'https://example.com/', token='test-only')

    def test_swap_upload_precedes_delete(self):
        calls = []
        release = {'assets': [{'name': 'appcast.xml', 'id': 1}]}
        with patch.object(publisher, 'upload', side_effect=lambda *a: calls.append('upload') or {'id': 2}), \
             patch.object(publisher, 'api', side_effect=lambda method, *a, **kw: calls.append(method)):
            publisher.swap('test', release, 'appcast.xml', b'new', 'application/xml')
        self.assertEqual(calls, ['upload', 'DELETE', 'PATCH'])

    def test_upload_failure_leaves_old_asset(self):
        with patch.object(publisher, 'upload', side_effect=RuntimeError('upload')), \
             patch.object(publisher, 'api') as api:
            with self.assertRaises(RuntimeError):
                publisher.swap('test', {'assets': []}, 'appcast.xml', b'new', 'application/xml')
        api.assert_not_called()

    def test_validation_failure_restores_previous_feed(self):
        release = {'assets': [{'name': 'appcast.xml'}]}
        validator = Mock(side_effect=RuntimeError('bad signature'))
        with patch.object(publisher, 'api', return_value=(200, release)), \
             patch.object(publisher, 'anonymous', return_value=b'old'), \
             patch.object(publisher, 'swap') as swap, \
             patch.object(publisher, 'check_public', return_value=b'new') as check:
            with self.assertRaisesRegex(RuntimeError, 'previous bytes restored'):
                publisher.replace_verified('test', 'appcast.xml', b'new', 'application/xml', validator)
        self.assertEqual([call.args[3] for call in swap.call_args_list], [b'new', b'old'])
        self.assertEqual(check.call_args_list[-1].args[1], b'old')

    def test_rollback_failure_is_not_reported_as_restored(self):
        release = {'assets': [{'name': 'appcast.xml'}]}
        with patch.object(publisher, 'api', return_value=(200, release)), \
             patch.object(publisher, 'anonymous', return_value=b'old'), \
             patch.object(publisher, 'swap', side_effect=RuntimeError('failed')):
            with self.assertRaisesRegex(RuntimeError, 'AND rollback failed'):
                publisher.replace_verified('test', 'appcast.xml', b'new', 'application/xml')

    def test_anonymous_retry_checks_bytes(self):
        with patch.object(publisher, 'anonymous', side_effect=[b'stale', b'new']) as fetch, \
             patch.object(publisher.time, 'sleep'):
            self.assertEqual(publisher.check_public('https://example.com/asset', b'new'), b'new')
        self.assertEqual(fetch.call_count, 2)

    def test_rejects_downgrade_or_changed_same_build(self):
        old = b'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><sparkle:version>11</sparkle:version></rss>'
        publisher.require_new_build(old, b'new', '12')
        publisher.require_new_build(old, old, '11')
        for build, feed in [('10', old), ('11', b'changed')]:
            with self.assertRaisesRegex(RuntimeError, 'Build must increase'):
                publisher.require_new_build(old, feed, build)

    def test_missing_live_build_stops(self):
        with self.assertRaisesRegex(RuntimeError, 'no build numbers'):
            publisher.require_new_build(b'<rss/>', b'new', '11')

    def test_full_publish_orders_assets_before_feed(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            dmg = root / 'Clockin-2.0.0-11.dmg'
            dmg.write_bytes(b'dmg')
            notes = root / 'notes.md'
            notes.write_text('Notes')
            (root / 'appcast.xml').write_bytes(b'new-feed')
            (root / 'SHA256SUMS').write_bytes(b'sums')
            commit = 'a' * 40
            events = []
            old_feed = b'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><sparkle:version>10</sparkle:version></rss>'

            def api(method, url, token, **kwargs):
                events.append((method, url, kwargs))
                if url == publisher.API and method == 'GET':
                    return 200, {'permissions': {'push': True}}
                if url.endswith('/commits/' + commit):
                    return 200, {'sha': commit}
                if url.endswith('/commits/macos-v2.0.0') or url.endswith('/releases/tags/macos-v2.0.0'):
                    return 404, None
                return 200, {'id': 3, 'draft': False, 'prerelease': False}

            def check(url, data):
                events.append(('anonymous-check', url, {}))
                return data

            def replace(token, name, data, content_type, validator=None):
                events.append(('replace', name, {}))

            with patch.object(publisher, 'OUTPUT', root), \
                 patch.object(publisher, 'local_release', return_value=(root, '11', dmg, notes, commit, root / 'Info.plist')), \
                 patch.object(publisher, 'github_token', return_value='fake'), \
                 patch.object(publisher, 'api', side_effect=api), \
                 patch.object(publisher, 'anonymous', side_effect=[old_feed, b'old-dmg']), \
                 patch.object(publisher, 'upload'), \
                 patch.object(publisher, 'check_public', side_effect=check), \
                 patch.object(publisher, 'replace_verified', side_effect=replace), \
                 contextlib.redirect_stdout(io.StringIO()):
                publisher.publish('2.0.0')
            order = [(event[0], event[1]) for event in events]
            self.assertLess(order.index(('anonymous-check', f'{publisher.BASE}/macos-v2.0.0/{dmg.name}')),
                            order.index(('replace', 'Clockin.dmg')))
            self.assertLess(order.index(('replace', 'Clockin.dmg')), order.index(('replace', 'appcast.xml')))
            mutations = [event[2]['body'] for event in events if 'body' in event[2]]
            self.assertTrue(mutations)
            self.assertTrue(all(body['make_latest'] == 'false' for body in mutations))


if __name__ == '__main__':
    if '--dry-run' in sys.argv:
        print('Run offline publisher checks with mocked network, credentials and external processes.')
    else:
        unittest.main()
