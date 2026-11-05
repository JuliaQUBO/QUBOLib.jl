#!/usr/bin/env python3
"""Synthetic byte/metadata guards; no catalogue models, objectives or proof replay."""
import copy
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile
import unittest

import check_derived_candidate as gate


class Fixture:
    def __init__(self, root):
        self.root = root
        self.assets = {}
        self.docs = {}
        self.root.joinpath('artifact').mkdir()
        self.old = self.pair('parent', b'old database', b'old HDF5')
        self.middle = self.pair('middle', b'old database + capture', b'old HDF5 + capture')
        self.final = self.pair('artifact', b'old database + capture + point', b'old HDF5 + capture + point')
        for name in ('parent_asset', 'raw', 'source_archive', 'all_states', 'endpoint'):
            self.put(name, ('inert bytes for ' + name).encode(), scope='release')
        for name in ('importer', 'support', 'helper', 'project', 'environment', 'capture_auditor', 'point_auditor', 'state'):
            self.put(name, ('inert bytes for ' + name).encode())
        package = {'package_revision': 'c' * 40, 'package_tree': 'd' * 40}
        self.capture_source = dict(repository='example/library', commit='a' * 40, importer='support',
                                   native_helper='helper', project='project', manifest='environment', **package)
        self.point_source = dict(repository='example/library', commit='b' * 40, importer='importer',
                                 support_importer='support', native_helper='helper', project='project', manifest='environment', **package)
        cap_counts = dict(bundles=1, preprocessing_records=4, solution_records=1, proof_records=1, unique_global_instances=1)
        point_counts = dict(preprocessing_records=0, solution_records=1, proof_records=0, unique_global_instances=0)
        self.cap = dict(kind='capture_append', instances=2, input_files=self.old, output_files=self.middle,
                        source=self.capture_source, audit='capture_audit', auditor='capture_auditor',
                        diff='capture_diff', plan='capture_plan', launch='capture_launch', counts=cap_counts)
        self.points = dict(kind='feasible_points', instances=2, input_files=self.middle, output_files=self.final,
                           source=self.point_source, audit='point_audit', auditor='point_auditor', diff='point_diff',
                           plan='point_plan', launch='point_launch', bundle='bundle', states={'7': 'state'},
                           instance_ids=[7], counts=point_counts)
        self.put_json('capture_plan', dict(argv=['julia', 'inert-capture.jl'], bundle_count=1,
            distinct_source_instances=2, importer={'sha256': self.assets['support']['sha256']},
            witness_helper={'sha256': self.assets['helper']['sha256']},
            producer_project={'sha256': self.assets['project']['sha256']},
            producer_manifest={'sha256': self.assets['environment']['sha256']}, **package))
        self.put_json('capture_launch', dict(plan_sha256=self.assets['capture_plan']['sha256'], command=['systemd', 'julia', 'inert-capture.jl']))
        self.put_json('capture_diff', dict(self.diff(self.cap), schema='qubolib-followup-stage-v1',
            expected_instance_count=2, importer_sha256=self.assets['support']['sha256']))
        cap_deltas = {table: dict(before=2, after=2 + delta, delta=delta) for table, delta in
                      dict(Collections=0, Instances=0, Solutions=1, Solvers=1, Submissions=1, SolutionRecords=1).items()}
        point_deltas = {table: dict(before=row['after'], after=row['after'] + row['delta'], delta=row['delta'])
                        for table, row in cap_deltas.items()}
        self.put_json('capture_audit', dict(schema='private-followup-stage-metadata-validation-v1', outcome='pass',
            old_columns_and_metadata_preserved=True, native_source_feasibility='unknown', original_hashes=gate.file_hashes(self.old),
            stage_hashes=gate.file_hashes(self.middle), diff_report_sha256=self.assets['capture_diff']['sha256'],
            preprocessing_records_added=4, retained_solution_records_added=1, proof_records_added=1,
            unique_exact_global_instances=1, instances_checked=2, validator_sha256=self.assets['capture_auditor']['sha256'], table_deltas=cap_deltas))
        self.put_json('point_plan', dict(argv=['julia', 'inert-points.jl']))
        self.put_json('point_launch', dict(source_commit='b' * 40, plan_sha256=self.assets['point_plan']['sha256'],
            dispatch_returncode=0, argv=['systemd', 'julia', 'inert-points.jl']))
        self.put_json('bundle', dict(schema='qubolib-validated-points-v1',
            parent_snapshot=dict(database_sha256=self.middle['index.db']['sha256'], archive_sha256=self.middle['archive.h5']['sha256']),
            points=[dict(instance_id=7, global_optimal=False, native_source_feasibility='unknown', state_file_sha256=self.assets['state']['sha256'])],
            provenance=package))
        self.put_json('point_diff', dict(self.diff(self.points), schema='qubolib-validated-point-stage-v1',
            bundle_sha256=self.assets['bundle']['sha256'], distinct_instances=1, importer_sha256=self.assets['importer']['sha256'],
            support_importer_sha256=self.assets['support']['sha256'], changes=[dict(instance_id=7, global_optimal=False)]))
        self.put_json('point_audit', dict(schema='six-point-private-stage-preservation-audit-v1', outcome='pass',
            instance_metadata_byte_identical=True, source_feasibility='unknown', parent_files=self.middle, stage_files=self.final, source_commit='b' * 40,
            import_diff=self.assets['point_diff'], bundle=self.assets['bundle'], import_plan=self.assets['point_plan'],
            launch_receipt=self.assets['point_launch'], auditor=self.assets['point_auditor'],
            executed_source_files={'importer': self.assets['importer'], 'support_importer': self.assets['support'], 'native_helper': self.assets['helper']},
            instances_preserved=2, new_solution_records=1, new_global_proofs=0, new_verified_feasible_instances=[7],
            point_state_files={'7': self.assets['state']}, unchanged_preprocessing_history_records=4,
            unchanged_capture_global_proof_records=1, unchanged_capture_global_instances=1, table_deltas=point_deltas,
            old_sql_rows_preserved={table: row['before'] for table, row in point_deltas.items()}))
        self.lineage = dict(schema='qubolib-derived-lineage-v1', historical_metadata_preserved=True,
            parent=dict(build_commit_status='not-reproducible', build_commit_note='Preserved mixed historical source states.',
                release_tag_commit='e' * 40, git_tree_sha1='f' * 40, instances=2, files=self.old, asset=self.assets['parent_asset']),
            assets=self.assets, reproduction=dict(parent_asset='parent_asset',
                parent_files={'index.db': 'parent_db', 'archive.h5': 'parent_h5'}, raw_evidence=['raw'],
                source_archives=['source_archive'], all_point_states='all_states', endpoint_audit='endpoint'), layers=[self.cap, self.points])
        self.manifest = dict(schema='qubolib-derived-release-v1', candidate=dict(release_target_commit='1' * 40,
            root='artifact', files=self.final, git_tree_sha1=self.independent_tree()))
        self.complete_execution_metadata()
        self.archive()
        self.seal()

    def complete_execution_metadata(self):
        # Match the actual producer formats while retaining entirely fabricated
        # bytes. Runtime paths describe the old execution, not the relocated files.
        def original(ref, path):
            return dict(bytes=self.assets[ref]['bytes'], sha256=self.assets[ref]['sha256'], path=path)
        self.cap['producer_commits'] = {'census': '9' * 40}
        self.assets['source_archive']['commit'] = '9' * 40
        c = self.docs['capture_plan']
        c.update(schema='private-combined-qubolib-stage-execution-plan-v1', artifact_tree='f' * 40, original_database=dict(self.old['index.db'], path='/data/parent/index.db'),
                 original_archive=dict(self.old['archive.h5'], path='/data/parent/archive.h5'),
                 importer=original('support', '/tools/capture/import_followup_results.jl'),
                 witness_helper=original('helper', '/producer/scripts/library_witnesses.jl'),
                 producer_project=original('project', '/producer/Project.toml'),
                 producer_manifest=original('environment', '/producer/Manifest.toml'),
                 julia=dict(path='/runtime/julia', bytes=1, sha256='8' * 64), output_directory='/data/middle',
                 phase_pins={'census': dict(root='/captures/census', source_revision='9' * 40, instances=2, records=4)},
                 bundles=[dict(path='/captures/census/jobs/slot-00', phase='census', slot=0, records=4, instance_ids=[1, 2],
                               metadata={name: original('raw', '/captures/census/jobs/slot-00/' + name)
                                         for name in ('run-plan.json', 'records.jsonl', 'terminal.json')})])
        c['argv'] = ['/runtime/julia', '--startup-file=no', '--project=/producer', c['importer']['path'],
            '--source-database=/data/parent/index.db', '--source-archive=/data/parent/archive.h5',
            '--database-sha256=' + self.old['index.db']['sha256'], '--archive-sha256=' + self.old['archive.h5']['sha256'],
            '--artifact-tree=' + 'f' * 40, '--run-id=capture-run', '--expected-instance-count=2',
            '--runs=/captures/census/jobs/slot-00', '--output=/data/middle',
            '--witness-tools=' + c['witness_helper']['path'], '--witness-tools-sha256=' + self.assets['helper']['sha256']]
        c['resource_argv'] = ['systemd'] + c['argv']
        self.put_json('capture_plan', c)
        self.put_json('capture_launch', dict(plan_sha256=self.assets['capture_plan']['sha256'], command=['systemd'] + c['argv']))
        d = self.docs['capture_diff'];d.update(run_id='capture-run', source_artifact_tree='f' * 40)
        d['verifier']['path'] = c['witness_helper']['path'];self.put_json('capture_diff', d)
        a = self.docs['capture_audit'];a['diff_report_sha256'] = self.assets['capture_diff']['sha256'];self.put_json('capture_audit', a)
        bundle = self.docs['bundle'];bundle.update(import_id='point-run', ancestor_snapshot=dict(artifact_tree='f' * 40,
            database_sha256=self.old['index.db']['sha256'], archive_sha256=self.old['archive.h5']['sha256']))
        bundle['provenance']['runner_commit'] = '9' * 40
        bundle['points'][0].update(state_path='states/7.bits', native_source_sha256='6' * 64,
                                   state_sha256='7' * 64, original_objective_exact='1/1')
        self.put_json('bundle', bundle)
        point = self.docs['point_plan'];point.update(schema='six-point-import-execution-plan-v1', bundle_sha256=self.assets['bundle']['sha256'],
            source_files={'scripts/import_validated_points.jl': self.assets['importer'],
                          'scripts/import_followup_results.jl': self.assets['support']},
            expected_deltas=dict(Instances=0, Solutions=1, SolutionRecords=1, Submissions=1, Solvers=1,
                                 preprocessing_runs=0, global_proof_records=0, unique_global_instances=0))
        point['argv'] = ['/runtime/julia', '--startup-file=no', '--project=/producer', '/tools/points/import_validated_points.jl',
            '--source-database=/data/middle/index.db', '--source-archive=/data/middle/archive.h5',
            '--database-sha256=' + self.middle['index.db']['sha256'], '--archive-sha256=' + self.middle['archive.h5']['sha256'],
            '--bundle=/points/points.json', '--bundle-sha256=' + self.assets['bundle']['sha256'], '--output=/data/final',
            '--witness-tools=' + c['witness_helper']['path'], '--witness-tools-sha256=' + self.assets['helper']['sha256']]
        self.put_json('point_plan', point)
        self.put_json('point_launch', dict(source_commit='b' * 40, plan_sha256=self.assets['point_plan']['sha256'],
                                         dispatch_returncode=0, argv=['systemd'] + point['argv']))
        d = self.docs['point_diff'];d.update(import_id='point-run', bundle_sha256=self.assets['bundle']['sha256'])
        d['verifier']['path'] = c['witness_helper']['path']
        d['changes'][0].update(source_sha256='6' * 64, state_sha256='7' * 64, original_objective_exact='1/1')
        self.put_json('point_diff', d)
        a = self.docs['point_audit']
        a.update(parent_files={n: dict(v, path='/data/middle/' + n) for n, v in self.middle.items()},
                 stage_files={n: dict(v, path='/data/final/' + n) for n, v in self.final.items()},
                 bundle=original('bundle', '/points/points.json'), import_diff=self.assets['point_diff'],
                 import_plan=self.assets['point_plan'], launch_receipt=self.assets['point_launch'],
                 executed_source_files={'importer': original('importer', '/tools/points/import_validated_points.jl'),
                    'support_importer': original('support', '/tools/points/import_followup_results.jl'),
                    'native_helper': c['witness_helper']}, point_state_files={'7': original('state', '/points/states/7.bits')})
        self.put_json('point_audit', a)

    def repin_plan(self, which, mutate):
        # Keep every containing digest, dispatched argv and audit binding valid.
        # The only remaining defect is the semantic contradiction under test.
        name = which + '_plan';old = copy.deepcopy(self.docs[name]);new = copy.deepcopy(old)
        mutate(new)
        if which == 'capture':
            new['resource_argv'] = new['resource_argv'][:-len(old['argv'])] + new['argv']
        self.put_json(name, new)
        launch_name = which + '_launch';launch = copy.deepcopy(self.docs[launch_name])
        launch['plan_sha256'] = self.assets[name]['sha256']
        command_key = 'command' if which == 'capture' else 'argv'
        launch[command_key] = launch[command_key][:-len(old['argv'])] + new['argv']
        self.put_json(launch_name, launch)
        if which == 'point':
            audit = copy.deepcopy(self.docs['point_audit'])
            audit['import_plan'] = self.assets[name];audit['launch_receipt'] = self.assets[launch_name]
            self.put_json('point_audit', audit)
        self.seal()

    def pair(self, directory, db, h5):
        path = self.root / directory
        path.mkdir(exist_ok=True)
        pair = {}
        for name, data in (('index.db', db), ('archive.h5', h5)):
            (path / name).write_bytes(data)
            pair[name] = dict(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        if directory == 'parent':
            for name, ref in (('index.db', 'parent_db'), ('archive.h5', 'parent_h5')):
                self.assets[ref] = dict(pair[name], path='parent/' + name, scope='release')
        return pair

    def put(self, name, data, scope='metadata'):
        path = self.root / (name + '.input')
        path.write_bytes(data)
        self.assets[name] = dict(path=path.name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest(), scope=scope)

    def put_json(self, name, document):
        self.docs[name] = document
        self.put(name, (json.dumps(document, sort_keys=True) + '\n').encode())
        self.assets[name]['format'] = 'json'

    def diff(self, layer):
        return dict(outcome='staged', historical_preprocessing_preserved=True, native_source_feasibility='unknown',
            source_database_sha256=layer['input_files']['index.db']['sha256'], source_archive_sha256=layer['input_files']['archive.h5']['sha256'],
            staged_database_sha256=layer['output_files']['index.db']['sha256'], staged_archive_sha256=layer['output_files']['archive.h5']['sha256'],
            preprocessing_records_added=layer['counts']['preprocessing_records'], solutions_added=layer['counts']['solution_records'],
            exact_global_proofs_added=layer['counts']['proof_records'], verifier={'sha256': self.assets['helper']['sha256']})

    def independent_tree(self):
        # Git's read-only hashing commands independently verify the implementation's
        # object framing. No index/ref/object writes or repository initialization.
        entries = b''
        for name in ('archive.h5', 'index.db'):
            blob = subprocess.check_output(['git', 'hash-object', str(self.root/'artifact'/name)], text=True).strip()
            entries += b'100644 ' + name.encode() + b'\0' + bytes.fromhex(blob)
        return subprocess.check_output(['git', 'hash-object', '-t', 'tree', '--stdin'], input=entries).decode().strip()

    def archive(self, extra=None, omit=None):
        path = self.root / 'qubolib.tar.gz'
        with tarfile.open(path, 'w:gz') as stream:
            for name in ('archive.h5', 'index.db'):
                if name != omit:
                    stream.add(self.root/'artifact'/name, arcname=name)
            if extra:
                info, content = extra
                stream.addfile(info, io.BytesIO(content))
        self.manifest['candidate']['archive'] = dict(path=path.name, bytes=path.stat().st_size, sha256=gate.sha(path))

    def seal(self):
        path = self.root / 'DERIVATION.json'
        path.write_text(json.dumps(self.lineage, sort_keys=True) + '\n')
        self.manifest['lineage'] = dict(path=path.name, bytes=path.stat().st_size, sha256=gate.sha(path))
        self.path = self.root / 'release-manifest.json'
        self.path.write_text(json.dumps(self.manifest, sort_keys=True) + '\n')
        self.approved = gate.sha(self.path)

    def validate(self, **kwargs):
        return gate.validate_manifest(self.path, self.approved, **kwargs)


class DerivedCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixture = Fixture(Path(self.temp.name))

    def test_complete_bytes_and_lineage(self):
        report = self.fixture.validate()
        self.assertTrue(report['artifact_validated'])
        self.assertFalse(report['publication_authorized'])
        self.assertEqual(report['deferred_release_assets'], [])

    def test_metadata_only_explicitly_defers_artifact(self):
        f = self.fixture
        f.manifest['candidate'] = None
        f.seal()
        (f.root / 'raw.input').unlink()
        report = f.validate(metadata_only=True)
        self.assertFalse(report['artifact_validated'])
        self.assertTrue(report['final_archive_validation_deferred'])
        self.assertIn('raw', report['deferred_release_assets'])
        with self.assertRaises((gate.ValidationError, TypeError)):
            f.validate()

    def test_missing_release_asset_fails_full(self):
        (self.fixture.root/'raw.input').unlink()
        with self.assertRaisesRegex(gate.ValidationError, 'Missing regular file'):
            self.fixture.validate()

    def test_approved_manifest_pin(self):
        self.fixture.path.write_text('{}')
        with self.assertRaisesRegex(gate.ValidationError, 'Approved release manifest'):
            self.fixture.validate()

    def test_lineage_pin(self):
        (self.fixture.root/'DERIVATION.json').write_text('{}')
        with self.assertRaises(gate.ValidationError):
            self.fixture.validate()

    def test_source_bytes_tampered(self):
        (self.fixture.root/'importer.input').write_bytes(b'other source')
        with self.assertRaises(gate.ValidationError):
            self.fixture.validate(metadata_only=True)

    def test_rejected_audit_even_with_updated_file_pin(self):
        f = self.fixture
        audit = copy.deepcopy(f.docs['capture_audit'])
        audit['old_columns_and_metadata_preserved'] = False
        f.put_json('capture_audit', audit)
        f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'Capture preservation'):
            f.validate()

    def test_historical_status_not_relabelled(self):
        f = self.fixture
        f.lineage['parent']['build_commit_status'] = 'verified'
        f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'historical parent'):
            f.validate()

    def test_broken_layer_chain(self):
        f = self.fixture
        f.points['input_files'] = f.old
        f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'layer chain'):
            f.validate()

    def test_points_cannot_add_proof_records(self):
        f = self.fixture
        f.points['counts']['proof_records'] = 1
        f.seal()
        with self.assertRaises(gate.ValidationError):
            f.validate()

    def test_point_global_scope_tamper(self):
        f = self.fixture
        bundle = copy.deepcopy(f.docs['bundle'])
        bundle['points'][0]['global_optimal'] = True
        f.put_json('bundle', bundle)
        # Deliberately preserve all cross-file pins after changing the claim.
        diff = copy.deepcopy(f.docs['point_diff']);diff['bundle_sha256'] = f.assets['bundle']['sha256']
        f.put_json('point_diff', diff)
        audit = copy.deepcopy(f.docs['point_audit']);audit['bundle'].update({k: f.assets['bundle'][k] for k in ('bytes', 'sha256')});audit['import_diff'] = f.assets['point_diff']
        f.put_json('point_audit', audit)
        def repin_bundle(plan):
            plan['bundle_sha256'] = f.assets['bundle']['sha256']
            plan['argv'] = ['--bundle-sha256=' + f.assets['bundle']['sha256'] if a.startswith('--bundle-sha256=') else a for a in plan['argv']]
        f.repin_plan('point', repin_bundle)
        with self.assertRaisesRegex(gate.ValidationError, 'must not become'):
            f.validate()

    def test_proof_union_preserved(self):
        f = self.fixture
        audit = copy.deepcopy(f.docs['point_audit']);audit['unchanged_capture_global_instances'] = 2
        f.put_json('point_audit', audit);f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'proof union'):
            f.validate()

    def test_archive_digest_tamper(self):
        with (self.fixture.root/'qubolib.tar.gz').open('ab') as stream:
            stream.write(b'tamper')
        with self.assertRaises(gate.ValidationError):
            self.fixture.validate()

    def test_archive_inventory_tamper(self):
        f = self.fixture
        for name, type_ in [('extra', tarfile.REGTYPE), ('index.db', tarfile.REGTYPE),
                            ('../outside', tarfile.REGTYPE), ('link', tarfile.SYMTYPE), ('hard', tarfile.LNKTYPE)]:
            with self.subTest(name=name, type=type_):
                info = tarfile.TarInfo(name);info.type=type_;info.mode=0o644
                f.archive(extra=(info, b''));f.seal()
                with self.assertRaisesRegex(gate.ValidationError, 'tar member'):
                    f.validate()
        f.archive(omit='index.db');f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'missing an artifact member'):
            f.validate()

    def test_candidate_files_changed(self):
        (self.fixture.root/'artifact/index.db').write_bytes(b'changed')
        with self.assertRaises(gate.ValidationError):
            self.fixture.validate()

    def test_extra_candidate_file(self):
        (self.fixture.root/'artifact/unlisted').write_bytes(b'')
        with self.assertRaisesRegex(gate.ValidationError, 'unexpected members'):
            self.fixture.validate()

    def test_wrong_tree_or_target(self):
        f = self.fixture
        f.manifest['candidate']['git_tree_sha1'] = '0' * 40;f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'Git tree'):
            f.validate()
        f.manifest['candidate']['release_target_commit'] = None;f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'release target'):
            f.validate()

    def test_unsafe_paths_and_symlinks(self):
        f = self.fixture
        f.assets['raw']['path'] = '../outside';f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'relative path'):
            f.validate()
        f.assets['raw']['path'] = 'raw.input';f.seal()
        (f.root/'raw.input').unlink();(f.root/'raw.input').symlink_to('source_archive.input')
        with self.assertRaisesRegex(gate.ValidationError, 'Missing regular file'):
            f.validate()

    def test_unknown_scope_and_duplicate_json(self):
        f = self.fixture
        f.assets['raw']['scope'] = 'optional';f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'Asset scope'):
            f.validate()
        f.path.write_text('{"schema":"x","schema":"y"}')
        with self.assertRaisesRegex(gate.ValidationError, 'Duplicate JSON'):
            gate.validate_manifest(f.path, gate.sha(f.path))

    def test_sql_row_preservation_coverage_required(self):
        f = self.fixture
        audit = copy.deepcopy(f.docs['point_audit']);audit['old_sql_rows_preserved'].pop('Solutions')
        f.put_json('point_audit', audit);f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'prior SQL row'):
            f.validate()

    def test_boolean_count_is_not_integer_zero(self):
        f = self.fixture
        diff = copy.deepcopy(f.docs['point_diff']);diff['exact_global_proofs_added'] = False
        f.put_json('point_diff', diff)
        audit = copy.deepcopy(f.docs['point_audit']);audit['import_diff'] = f.assets['point_diff']
        f.put_json('point_audit', audit);f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'diff counts'):
            f.validate()

    def test_layer_sizes_must_connect(self):
        f = self.fixture
        f.points['input_files'] = copy.deepcopy(f.middle)
        f.points['input_files']['index.db']['bytes'] += 1;f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'layer chain'):
            f.validate()

    def test_final_sizes_match_last_layer(self):
        f = self.fixture
        f.manifest['candidate']['files'] = copy.deepcopy(f.final)
        f.manifest['candidate']['files']['index.db']['bytes'] += 1;f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'last layer'):
            f.validate()

    def test_audit_cannot_upgrade_native_feasibility(self):
        f = self.fixture
        audit = copy.deepcopy(f.docs['point_audit']);audit['source_feasibility'] = 'feasible'
        f.put_json('point_audit', audit);f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'native feasibility'):
            f.validate()

    def test_repinned_point_plan_bundle_pin(self):
        self.fixture.repin_plan('point', lambda p: p.update(bundle_sha256='0' * 64))
        with self.assertRaises(gate.ValidationError):
            self.fixture.validate(metadata_only=True)

    def test_repinned_point_plan_executed_sources(self):
        for source in ('scripts/import_validated_points.jl', 'scripts/import_followup_results.jl'):
            with self.subTest(source=source):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path))
                    f.repin_plan('point', lambda p: p['source_files'][source].update(sha256='0' * 64))
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_repinned_parent_tree_must_match_execution(self):
        f = self.fixture;f.lineage['parent']['git_tree_sha1'] = '0' * 40;f.seal()
        with self.assertRaises(gate.ValidationError):
            f.validate(metadata_only=True)

    def test_repinned_hash_arguments_match_inputs(self):
        flags = {'capture': ('database-sha256', 'archive-sha256', 'artifact-tree', 'witness-tools-sha256'),
                 'point': ('database-sha256', 'archive-sha256', 'bundle-sha256', 'witness-tools-sha256')}
        for which, names in flags.items():
            for name in names:
                with self.subTest(which=which, flag=name):
                    with tempfile.TemporaryDirectory() as path:
                        f = Fixture(Path(path))
                        def contradict(plan):
                            plan['argv'] = ['--' + name + '=' + '0' * (40 if name == 'artifact-tree' else 64)
                                            if a.startswith('--' + name + '=') else a for a in plan['argv']]
                        f.repin_plan(which, contradict)
                        with self.assertRaises(gate.ValidationError):
                            f.validate(metadata_only=True)

    def test_repinned_execution_paths_and_selection(self):
        for which, name in (('capture', 'source-database'), ('capture', 'source-archive'), ('capture', 'runs'),
                            ('capture', 'witness-tools'), ('capture', 'output'), ('point', 'source-database'),
                            ('point', 'source-archive'), ('point', 'bundle'), ('point', 'witness-tools'), ('point', 'output')):
            with self.subTest(which=which, flag=name):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path))
                    def contradict(plan):
                        plan['argv'] = ['--' + name + '=/different/input' if a.startswith('--' + name + '=') else a
                                        for a in plan['argv']]
                    f.repin_plan(which, contradict)
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_repinned_parent_file_and_environment_plan_records(self):
        for name in ('original_database', 'original_archive', 'producer_project', 'producer_manifest', 'importer', 'witness_helper'):
            with self.subTest(field=name):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path))
                    f.repin_plan('capture', lambda p: p[name].update(bytes=p[name]['bytes'] + 1))
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_repinned_duplicate_identity_argument(self):
        f = self.fixture
        f.repin_plan('point', lambda p: p['argv'].append('--bundle-sha256=' + '0' * 64))
        with self.assertRaises(gate.ValidationError):
            f.validate(metadata_only=True)

    def test_repinned_capture_raw_bundle_selection(self):
        f = self.fixture
        f.repin_plan('capture', lambda p: p['bundles'][0].update(path='/other/raw-bundle'))
        with self.assertRaises(gate.ValidationError):
            f.validate(metadata_only=True)

    def test_repinned_runtime_project_and_script_paths(self):
        for which, part in (('point', 'runtime'), ('point', 'project'), ('point', 'script'), ('capture', 'script')):
            with self.subTest(which=which, part=part):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path))
                    def contradict(plan):
                        if part == 'runtime':
                            plan['argv'][0] = '/other/julia'
                        elif part == 'project':
                            plan['argv'][2] = '--project=/other/project'
                        else:
                            plan['argv'][3] = '/other/' + PurePosixPath(plan['argv'][3]).name
                    f.repin_plan(which, contradict)
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_repinned_raw_phase_metadata_and_source(self):
        for field in ('producer', 'record_total', 'metadata_path'):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path))
                    def contradict(plan):
                        if field == 'producer':
                            plan['phase_pins']['census']['source_revision'] = '0' * 40
                        elif field == 'record_total':
                            plan['bundles'][0]['records'] += 1
                        else:
                            plan['bundles'][0]['metadata']['records.jsonl']['path'] = '/unselected/records.jsonl'
                    f.repin_plan('capture', contradict)
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_repinned_point_planned_proof_delta(self):
        f = self.fixture
        f.repin_plan('point', lambda p: p['expected_deltas'].update(global_proof_records=1))
        with self.assertRaisesRegex(gate.ValidationError, 'planned deltas'):
            f.validate(metadata_only=True)

    def test_repinned_point_raw_source_and_state_paths(self):
        for field in ('source_sha256', 'state_sha256', 'original_objective_exact', 'state_path'):
            with self.subTest(field=field):
                with tempfile.TemporaryDirectory() as path:
                    f = Fixture(Path(path));audit = copy.deepcopy(f.docs['point_audit'])
                    if field == 'state_path':
                        audit['point_state_files']['7']['path'] = '/other/7.bits'
                    else:
                        diff = copy.deepcopy(f.docs['point_diff'])
                        diff['changes'][0][field] = '2/1' if field == 'original_objective_exact' else '0' * 64
                        f.put_json('point_diff', diff);audit['import_diff'] = f.assets['point_diff']
                    f.put_json('point_audit', audit);f.seal()
                    with self.assertRaises(gate.ValidationError):
                        f.validate(metadata_only=True)

    def test_uniform_build_cannot_enter_derived_route(self):
        f = self.fixture
        f.lineage['schema'] = 'uniform-clean-build';f.seal()
        with self.assertRaisesRegex(gate.ValidationError, 'uniform builds'):
            f.validate()


if __name__ == '__main__':
    unittest.main(verbosity=2)
