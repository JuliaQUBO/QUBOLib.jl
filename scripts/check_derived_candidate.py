#!/usr/bin/env python3
"""Validate a layered candidate's pinned receipts and bytes, without model evaluation.

This is an explicit alternative for append-only derivations, not a relaxation of
release_check.jl or the uniform clean-build provenance policy in RELEASE.md.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import tarfile


class ValidationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def hexhash(value, length=64):
    return isinstance(value, str) and re.fullmatch('[0-9a-f]{' + str(length) + '}', value) is not None


def integer(value, minimum=0):
    return type(value) is int and value >= minimum


def load_json(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'Duplicate JSON key: ' + key)
            result[key] = value
        return result
    with Path(path).open(encoding='utf-8') as stream:
        return json.load(stream, object_pairs_hook=unique,
                         parse_constant=lambda value: (_ for _ in ()).throw(ValidationError('Nonfinite JSON number: ' + value)))


def digest_stream(stream, algorithm='sha256', prefix=b''):
    digest = hashlib.new(algorithm)
    digest.update(prefix)
    for block in iter(lambda: stream.read(8 << 20), b''):
        digest.update(block)
    return digest.hexdigest()


def sha(path):
    with Path(path).open('rb') as stream:
        return digest_stream(stream)


def binding(record):
    require(isinstance(record, dict) and hexhash(record.get('sha256')) and
            integer(record.get('bytes')), 'Expected file size and lowercase SHA256')


def safe_relative(value):
    require(isinstance(value, str) and value and '\\' not in value, 'Expected relative POSIX path')
    path = PurePosixPath(value)
    require(not path.is_absolute() and all(part not in ('..', '.') for part in path.parts) and
            str(path) == value, 'Unsafe or noncanonical relative path: ' + value)
    return path


def checked_file(path, expected):
    binding(expected)
    path = Path(path)
    require(not path.is_symlink() and path.is_file(), 'Missing regular file: ' + str(path))
    require(path.stat().st_size == expected['bytes'], 'File size differs: ' + str(path))
    require(sha(path) == expected['sha256'], 'File SHA256 differs: ' + str(path))
    return path


def file_hashes(files):
    require(isinstance(files, dict) and set(files) == {'index.db', 'archive.h5'}, 'Expected database/archive pair')
    for record in files.values():
        binding(record)
    return {key: record['sha256'] for key, record in files.items()}


def count_is(value, expected):
    return type(value) is int and value == expected


def table_deltas(audit, expected):
    observed = audit.get('table_deltas', {})
    require(set(observed) == set(expected), 'Preservation audit table inventory differs')
    for table, delta in expected.items():
        record = observed[table]
        require(integer(record.get('before')) and integer(record.get('after')) and
                count_is(record.get('delta'), delta) and record['after'] - record['before'] == delta,
                'Preservation audit table delta differs: ' + table)


def check_diff(diff, layer, parent_files, output_files):
    counts = layer['counts']
    require(diff.get('outcome') == 'staged' and diff.get('historical_preprocessing_preserved') is True,
            'Import diff must report committed append-only staging')
    require(diff.get('source_database_sha256') == parent_files['index.db'] and
            diff.get('source_archive_sha256') == parent_files['archive.h5'] and
            diff.get('staged_database_sha256') == output_files['index.db'] and
            diff.get('staged_archive_sha256') == output_files['archive.h5'], 'Import diff breaks layer file chain')
    require(count_is(diff.get('preprocessing_records_added'), counts['preprocessing_records']) and
            count_is(diff.get('solutions_added'), counts['solution_records']) and
            count_is(diff.get('exact_global_proofs_added'), counts['proof_records']), 'Import diff counts differ')
    require(diff.get('native_source_feasibility') == 'unknown', 'Do not upgrade native-source feasibility')


def check_capture(layer, audit, diff, plan, launch, assets):
    counts = layer['counts']
    require(audit.get('native_source_feasibility') == 'unknown', 'Capture audit must not upgrade native feasibility')
    require(isinstance(plan.get('argv'), list) and plan['argv'] and all(isinstance(a, str) for a in plan['argv']),
            'Capture execution argv is required')
    require(audit.get('schema') == 'private-followup-stage-metadata-validation-v1' and
            audit.get('outcome') == 'pass' and audit.get('old_columns_and_metadata_preserved') is True,
            'Capture preservation audit is missing or rejected')
    require(audit.get('original_hashes') == file_hashes(layer['input_files']) and
            audit.get('stage_hashes') == file_hashes(layer['output_files']), 'Capture audit file pins differ')
    require(audit.get('diff_report_sha256') == assets[layer['diff']]['sha256'], 'Capture audit/diff binding differs')
    for field, count in (('preprocessing_records_added', 'preprocessing_records'),
                         ('retained_solution_records_added', 'solution_records'),
                         ('proof_records_added', 'proof_records'),
                         ('unique_exact_global_instances', 'unique_global_instances')):
        require(count_is(audit.get(field), counts[count]), 'Capture audit count differs: ' + field)
    require(count_is(audit.get('instances_checked'), layer['instances']), 'Capture audit instance coverage differs')
    require(diff.get('schema') == 'qubolib-followup-stage-v1' and
            diff.get('expected_instance_count') == layer['instances'], 'Capture diff scope differs')
    require(diff.get('importer_sha256') == assets[layer['source']['importer']]['sha256'], 'Capture importer source differs')
    require(count_is(plan.get('bundle_count'), counts['bundles']) and integer(counts['bundles'], 1) and
            plan.get('distinct_source_instances') == layer['instances'], 'Capture bundle plan coverage differs')
    require(plan.get('importer', {}).get('sha256') == diff['importer_sha256'], 'Capture plan importer differs')
    require(audit.get('validator_sha256') == assets[layer['auditor']]['sha256'], 'Capture auditor source differs')
    require(launch.get('plan_sha256') == assets[layer['plan']]['sha256'] and
            launch.get('command', [])[-len(plan['argv']):] == plan['argv'], 'Capture dispatched plan differs')
    require(plan.get('package_revision') == layer['source']['package_revision'] and
            plan.get('package_tree') == layer['source']['package_tree'], 'Capture package identity differs')
    require(plan.get('witness_helper', {}).get('sha256') == assets[layer['source']['native_helper']]['sha256'] and
            diff.get('verifier', {}).get('sha256') == assets[layer['source']['native_helper']]['sha256'],
            'Capture native helper identity differs')
    table_deltas(audit, dict(Collections=0, Instances=0, Solutions=counts['solution_records'],
                             Solvers=1, Submissions=counts['bundles'], SolutionRecords=counts['solution_records']))
    require(plan.get('producer_project', {}).get('sha256') == assets[layer['source']['project']]['sha256'] and
            plan.get('producer_manifest', {}).get('sha256') == assets[layer['source']['manifest']]['sha256'],
            'Capture environment pins differ')


def check_points(layer, audit, diff, bundle, plan, launch, assets):
    counts = layer['counts']
    require(audit.get('source_feasibility') == 'unknown', 'Point audit must not upgrade native feasibility')
    require(isinstance(plan.get('argv'), list) and plan['argv'] and all(isinstance(a, str) for a in plan['argv']),
            'Point execution argv is required')
    require(audit.get('schema') == 'six-point-private-stage-preservation-audit-v1' and
            audit.get('outcome') == 'pass' and audit.get('instance_metadata_byte_identical') is True,
            'Point preservation audit is missing or rejected')
    require({k: v['sha256'] for k, v in audit.get('parent_files', {}).items()} == file_hashes(layer['input_files']) and
            {k: v['sha256'] for k, v in audit.get('stage_files', {}).items()} == file_hashes(layer['output_files']),
            'Point audit file pins differ')
    require(audit.get('source_commit') == layer['source']['commit'], 'Point producing source commit differs')
    for field, ref in (('import_diff', 'diff'), ('bundle', 'bundle'), ('import_plan', 'plan'),
                       ('launch_receipt', 'launch'), ('auditor', 'auditor')):
        require(audit.get(field, {}).get('sha256') == assets[layer[ref]]['sha256'], 'Point audit binding differs: ' + field)
    for name in ('importer', 'support_importer', 'native_helper'):
        require(audit.get('executed_source_files', {}).get(name, {}).get('sha256') ==
                assets[layer['source'][name]]['sha256'], 'Point executed source differs: ' + name)
    require(audit.get('instances_preserved') == layer['instances'] and
            audit.get('new_solution_records') == counts['solution_records'] and
            audit.get('new_global_proofs') == 0 and counts['preprocessing_records'] == counts['proof_records'] == counts['unique_global_instances'] == 0,
            'Point audit scope/counts differ')
    require(diff.get('schema') == 'qubolib-validated-point-stage-v1' and
            diff.get('bundle_sha256') == assets[layer['bundle']]['sha256'], 'Point diff bundle differs')
    require(bundle.get('schema') == 'qubolib-validated-points-v1' and
            bundle.get('parent_snapshot', {}).get('database_sha256') == layer['input_files']['index.db']['sha256'] and
            bundle.get('parent_snapshot', {}).get('archive_sha256') == layer['input_files']['archive.h5']['sha256'],
            'Point bundle parent differs')
    require(count_is(diff.get('distinct_instances'), counts['solution_records']), 'Point distinct-instance count differs')
    table_deltas(audit, dict(Collections=0, Instances=0, Solutions=counts['solution_records'],
                             Solvers=1, Submissions=1, SolutionRecords=counts['solution_records']))
    require(audit.get('old_sql_rows_preserved') == {table: row['before'] for table, row in audit['table_deltas'].items()},
            'Point audit prior SQL row coverage differs')
    points = bundle.get('points', [])
    ids = [point.get('instance_id') for point in points]
    require(all(integer(iid, 1) for iid in ids) and len(ids) == len(set(ids)) == counts['solution_records'] and sorted(ids) == layer['instance_ids'] and
            sorted(audit.get('new_verified_feasible_instances', [])) == sorted(ids), 'Point inventory differs')
    require(all(point.get('global_optimal') is False and point.get('native_source_feasibility') == 'unknown'
                for point in points), 'Feasible points must not become global/native proofs')
    require(all(change.get('global_optimal') is False for change in diff.get('changes', [])) and
            sorted(change.get('instance_id') for change in diff.get('changes', [])) == sorted(ids), 'Point diff inventory differs')
    require(diff.get('importer_sha256') == assets[layer['source']['importer']]['sha256'] and
            diff.get('support_importer_sha256') == assets[layer['source']['support_importer']]['sha256'] and
            diff.get('verifier', {}).get('sha256') == assets[layer['source']['native_helper']]['sha256'],
            'Point importer/helper identities differ')
    require(launch.get('source_commit') == layer['source']['commit'] and
            launch.get('plan_sha256') == assets[layer['plan']]['sha256'] and launch.get('dispatch_returncode') == 0 and
            launch.get('argv', [])[-len(plan['argv']):] == plan['argv'], 'Point dispatched source/plan differs')
    require(bundle.get('provenance', {}).get('package_revision') == layer['source']['package_revision'] and
            bundle.get('provenance', {}).get('package_tree') == layer['source']['package_tree'], 'Point producer package identity differs')
    require(set(layer['states']) == {str(iid) for iid in ids}, 'Point state asset inventory differs')
    for point in points:
        iid = str(point['instance_id'])
        asset = assets[layer['states'][iid]]
        require(asset['sha256'] == point['state_file_sha256'] and
                audit.get('point_state_files', {}).get(iid, {}).get('sha256') == asset['sha256'],
                'Point state file binding differs')


def validate_lineage(lineage, base, locations, metadata_only):
    require(lineage.get('schema') == 'qubolib-derived-lineage-v1', 'Wrong lineage schema; uniform builds use the existing gate')
    require(lineage.get('historical_metadata_preserved') is True, 'Historical metadata must be preserved')
    parent = lineage['parent']
    require(parent.get('build_commit_status') == 'not-reproducible' and
            isinstance(parent.get('build_commit_note'), str) and parent['build_commit_note'].strip(),
            'Preserve the historical parent provenance limitation')
    require(hexhash(parent.get('release_tag_commit'), 40) and hexhash(parent.get('git_tree_sha1'), 40), 'Parent commit/tree pin is required')
    binding(parent['asset'])
    assets = lineage['assets']
    require(isinstance(assets, dict) and assets and not (set(locations) - set(assets)), 'Invalid asset inventory/location map')
    documents, deferred = {}, []
    for name, asset in assets.items():
        binding(asset)
        safe_relative(asset['path'])
        require(asset.get('scope') in ('metadata', 'release'), 'Asset scope must be metadata or release')
        if metadata_only and asset['scope'] == 'release':
            deferred.append(name)
            continue
        path = checked_file(locations.get(name, base / asset['path']), asset)
        if asset.get('format') == 'json':
            documents[name] = load_json(path)
    reproduction = lineage['reproduction']
    require(assets[reproduction['parent_asset']]['sha256'] == parent['asset']['sha256'] and
            assets[reproduction['parent_asset']]['bytes'] == parent['asset']['bytes'], 'Published parent asset binding differs')
    require(set(reproduction['parent_files']) == set(parent['files']), 'Parent file asset inventory differs')
    for name, ref in reproduction['parent_files'].items():
        require(assets[ref]['sha256'] == parent['files'][name]['sha256'] and
                assets[ref]['bytes'] == parent['files'][name]['bytes'], 'Parent input file asset differs')
    require(isinstance(reproduction.get('raw_evidence'), list) and reproduction['raw_evidence'] and
            isinstance(reproduction.get('source_archives'), list) and reproduction['source_archives'],
            'Raw evidence and producer source archives are required')
    for ref in reproduction['raw_evidence'] + reproduction['source_archives'] + [reproduction['all_point_states'], reproduction['endpoint_audit']]:
        require(ref in assets and assets[ref]['scope'] == 'release', 'Missing release reproduction asset: ' + ref)
    layers = lineage['layers']
    require(isinstance(layers, list) and [layer.get('kind') for layer in layers] == ['capture_append', 'feasible_points'],
            'This schema requires capture append followed by separate feasible points')
    previous = file_hashes(parent['files'])
    previous_records = parent['files']
    for layer in layers:
        require(layer.get('instances') == parent.get('instances') and integer(layer['instances'], 1), 'Instance scope changed')
        require(file_hashes(layer['input_files']) == previous and layer['input_files'] == previous_records,
                'Broken input/output layer chain')
        output = file_hashes(layer['output_files'])
        source = layer['source']
        require(hexhash(source.get('commit'), 40) and isinstance(source.get('repository'), str), 'Committed importer identity is required')
        require(hexhash(source.get('package_revision'), 40) and hexhash(source.get('package_tree'), 40),
                'Exact package revision/tree pins are required')
        for name in ('preprocessing_records', 'solution_records', 'proof_records', 'unique_global_instances'):
            require(integer(layer['counts'].get(name)), 'Invalid layer count: ' + name)
        audit, diff = documents[layer['audit']], documents[layer['diff']]
        check_diff(diff, layer, previous, output)
        if layer['kind'] == 'capture_append':
            check_capture(layer, audit, diff, documents[layer['plan']], documents[layer['launch']], assets)
        else:
            check_points(layer, audit, diff, documents[layer['bundle']], documents[layer['plan']], documents[layer['launch']], assets)
            previous_audit = documents[layers[0]['audit']]
            require({t: r['after'] for t, r in previous_audit['table_deltas'].items()} ==
                    {t: r['before'] for t, r in audit['table_deltas'].items()}, 'SQL audit layer counts do not connect')
            first = layers[0]['counts']
            require(audit.get('unchanged_preprocessing_history_records') == first['preprocessing_records'] and
                    audit.get('unchanged_capture_global_proof_records') == first['proof_records'] and
                    audit.get('unchanged_capture_global_instances') == first['unique_global_instances'],
                    'Point layer changed capture histories/proof union')
        previous = output
        previous_records = layer['output_files']
    return previous_records, deferred


def tree_hash(root, names):
    """Git tree of the flat regular-file artifact, using Git object framing."""
    entries = bytearray()
    for name in sorted(names, key=lambda name: name.encode('utf-8')):
        path = root / name
        mode = path.stat().st_mode
        require(stat.S_ISREG(mode) and not mode & 0o111, 'Artifact files must have ordinary nonexecutable mode')
        with path.open('rb') as stream:
            blob = digest_stream(stream, 'sha1', f'blob {path.stat().st_size}\0'.encode())
        entries.extend(b'100644 ' + name.encode('utf-8') + b'\0' + bytes.fromhex(blob))
    return hashlib.sha1(f'tree {len(entries)}\0'.encode() + entries).hexdigest()


def validate_artifact(candidate, base, final_files, artifact_root):
    require(hexhash(candidate.get('release_target_commit'), 40), 'Committed release target is required')
    require(hexhash(candidate.get('git_tree_sha1'), 40), 'Final artifact tree hash is required')
    files = candidate['files']
    require(set(files) == {'index.db', 'archive.h5'}, 'Final artifact must contain only the database and HDF5')
    require(files == final_files, 'Final files differ from last layer')
    root = Path(artifact_root) if artifact_root else base / safe_relative(candidate['root'])
    require(not root.is_symlink() and root.is_dir(), 'Final artifact directory is missing')
    require({p.name for p in root.iterdir()} == set(files), 'Final artifact has missing or unexpected members')
    for name, record in files.items():
        checked_file(root / name, record)
    require(tree_hash(root, files) == candidate['git_tree_sha1'], 'Artifact Git tree differs')
    archive = candidate['archive']
    safe_relative(archive['path'])
    archive_path = checked_file(base / archive['path'], archive)
    seen = set()
    with tarfile.open(archive_path, mode='r|gz') as stream:
        for member in stream:
            require(member.name in files and member.name not in seen and member.isfile() and
                    member.mode == 0o644, 'Unexpected, duplicate, linked or noncanonical tar member')
            seen.add(member.name)
            require(member.size == files[member.name]['bytes'], 'Tar member size differs')
            with stream.extractfile(member) as content:
                require(digest_stream(content) == files[member.name]['sha256'], 'Tar member bytes differ')
    require(seen == set(files), 'Tar is missing an artifact member')


def validate_manifest(path, expected_sha256, *, metadata_only=False, locations=None, artifact_root=None):
    path = Path(path)
    require(hexhash(expected_sha256) and sha(path) == expected_sha256, 'Approved release manifest SHA256 differs')
    manifest = load_json(path)
    require(manifest.get('schema') == 'qubolib-derived-release-v1', 'Wrong release manifest schema')
    base = path.parent
    lineage_binding = manifest['lineage']
    safe_relative(lineage_binding['path'])
    lineage_path = checked_file(base / lineage_binding['path'], lineage_binding)
    final_files, deferred = validate_lineage(load_json(lineage_path), base, locations or {}, metadata_only)
    if not metadata_only:
        validate_artifact(manifest['candidate'], base, final_files, artifact_root)
    return {'schema': 'qubolib-derived-validation-v1',
            'outcome': 'metadata_validated' if metadata_only else 'artifact_bytes_and_lineage_validated',
            'manifest_sha256': expected_sha256, 'lineage_sha256': lineage_binding['sha256'],
            'validator_sha256': sha(Path(__file__)),
            'artifact_validated': not metadata_only, 'deferred_release_assets': deferred,
            'final_archive_validation_deferred': metadata_only,
            'publication_authorized': False,
            'scope': 'Pinned lineage/receipt consistency and byte identity; no SQL audit, model/objective evaluation or proof replay',
            'remaining_gate': 'Independent source/content audit and maintainer publication authorization remain separate'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--manifest', required=True, type=Path)
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--metadata-only', action='store_true')
    parser.add_argument('--asset-locations', type=Path, help='JSON map from asset IDs to existing file paths; changes locations, never hashes')
    parser.add_argument('--artifact-root', type=Path)
    args = parser.parse_args()
    try:
        report = validate_manifest(args.manifest, args.manifest_sha256, metadata_only=args.metadata_only,
                                   locations=load_json(args.asset_locations) if args.asset_locations else None,
                                   artifact_root=args.artifact_root)
    except (ValidationError, OSError, KeyError, TypeError, json.JSONDecodeError, tarfile.TarError) as error:
        parser.exit(1, 'Derived candidate validation failed: ' + str(error) + '\n')
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
