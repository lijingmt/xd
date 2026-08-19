const assert = require('assert');
const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..', '..');
const { buildWorldMap, inferBiome } = require(
    path.join(rootDir, 'scripts', 'build', 'generate_world_map.js')
);

const graph = buildWorldMap(path.join(rootDir, 'gamelib', 'd'));
assert.strictEqual(graph.schema, 1);
assert(graph.roomCount >= 2500, 'the complete world must include ordinary, dungeon and S1 rooms');
assert(graph.edgeCount >= 2400, 'the complete world must preserve room connections');
assert(graph.regionCount >= 60, 'the complete world must preserve map regions');
assert(graph.unresolvedExitCount <= 10, 'too many real room exits were lost');
assert(graph.bounds.width > 8000 && graph.bounds.height > 8000,
    'world bounds must be large enough to represent separate regions');
assert(graph.bounds.height / graph.bounds.width < 2.5,
    'world packing must remain usable on a widescreen canvas');

const ids = new Set();
const nodeById = new Map();
for (const node of graph.nodes) {
    assert(!ids.has(node.id), `duplicate room id: ${node.id}`);
    ids.add(node.id);
    nodeById.set(node.id, node);
    assert(node.name, `room has no display name: ${node.id}`);
    assert(Number.isFinite(node.x) && Number.isFinite(node.y),
        `room has no stable map coordinate: ${node.id}`);
    assert(['plains', 'forest', 'mountain', 'snow', 'desert', 'marsh', 'coast', 'city', 'abyss'].includes(node.biome),
        `room has unsupported biome: ${node.id}`);
}
for (const node of graph.nodes) {
    for (const exit of node.exits) {
        assert(nodeById.has(exit.target),
            `room exit points outside generated graph: ${node.id} -> ${exit.target}`);
    }
}

const moonGate = nodeById.get('illusion_s1/moon_gate');
assert(moonGate, 'S1 moon gate must appear on the complete world map');
assert(moonGate.exits.some(exit => exit.direction === 'east' &&
    exit.target === 'illusion_s1/silver_path'),
    'S1 room topology must preserve the real eastward route');
assert.strictEqual(inferBiome({ id: 'world/snow_field', name: '寒霜雪原', description: '' }), 'snow');
assert.strictEqual(inferBiome({ id: 'world/old_city', name: '古城', description: '' }), 'city');

const atlasPath = path.join(rootDir, 'images', 'visual_map', 'world-terrain-atlas-v1.webp');
assert(fs.existsSync(atlasPath), 'AI-authored world terrain atlas is missing');
assert(fs.statSync(atlasPath).size > 200 * 1024 && fs.statSync(atlasPath).size < 900 * 1024,
    'world terrain atlas must remain production-sized');

console.log(`World map graph tests passed (${graph.roomCount} rooms, ${graph.edgeCount} links, ${graph.regionCount} regions).`);
