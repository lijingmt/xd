#!/usr/bin/env node
'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const DIRECTION_VECTORS = {
  north: [0, -1],
  south: [0, 1],
  east: [1, 0],
  west: [-1, 0],
  northeast: [1, -1],
  northwest: [-1, -1],
  southeast: [1, 1],
  southwest: [-1, 1],
  up: [0.55, -0.75],
  down: [-0.55, 0.75],
  out: [1, 1],
  enter: [-1, -1]
};

function walkFiles(root) {
  const files = [];
  const visit = (directory) => {
    for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
      if (entry.name.startsWith('.')) continue;
      const fullPath = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(fullPath);
      else if (entry.isFile()) files.push(fullPath);
    }
  };
  visit(root);
  return files.sort();
}

function decodePikeString(value) {
  return String(value || '')
    .replace(/\\n/g, ' ')
    .replace(/\\t/g, ' ')
    .replace(/\\r/g, ' ')
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, '\\')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeRoomId(value) {
  return String(value || '')
    .replace(/^\/+/, '')
    .replace(/^gamelib\/d\//, '')
    .replace(/\.pike$/, '')
    .replace(/\/{2,}/g, '/');
}

function inferBiome(room) {
  const clue = [room.id, room.name, room.description].join(' ').toLowerCase();
  if (/(illusion|huanjing|mijing|shenyuan|gui|mojie|xukong|abyss|moon|幻|渊|冥|虚空|魔)/.test(clue)) return 'abyss';
  if (/(cheng|zhen|gong|dian|jie|guangchang|zhuang|shop|city|城|镇|宫|殿|街|庄|阁|铺)/.test(clue)) return 'city';
  if (/(xue|bing|leng|han|frost|snow|雪|冰|寒|霜)/.test(clue)) return 'snow';
  if (/(hai|shui|tan|he|jiang|hu|gang|wan|coast|sea|海|水|潭|河|江|湖|港|湾)/.test(clue)) return 'coast';
  if (/(zhaoze|shi(di|lin)|marsh|swamp|沼|湿地|泥潭)/.test(clue)) return 'marsh';
  if (/(huang|sha|desert|waste|荒|沙|漠)/.test(clue)) return 'desert';
  if (/(lin|sen|mu|shu|zhu|forest|wood|林|森|木|树|竹)/.test(clue)) return 'forest';
  if (/(shan|feng|ya|dong|gu|ling|mount|cave|山|峰|崖|洞|谷|岭)/.test(clue)) return 'mountain';
  return 'plains';
}

function parseRoomFile(filePath, roomRoot) {
  const source = fs.readFileSync(filePath, 'utf8');
  if (!/^\s*inherit\s+WAP_ROOM\s*;/m.test(source)) return null;
  const relativePath = path.relative(roomRoot, filePath).split(path.sep).join('/');
  const id = normalizeRoomId(relativePath);
  if (!id || /(^|\/)(create_room|create_city|convert_stdout\.log)$/.test(id)) return null;
  const nameMatch = source.match(/\bname_cn\s*=\s*"((?:\\.|[^"\\])*)"/);
  const descriptionMatch = source.match(/\bdesc\s*=\s*"((?:\\.|[^"\\])*)"/);
  const levelMatch = source.match(/\broom_level\s*=\s*(\d+)/);
  const exits = [];
  const exitPattern = /\bexits\s*\[\s*"([^"]+)"\s*\]\s*=\s*ROOT\s*"\/gamelib\/d\/([^"]+)"/g;
  let match;
  while ((match = exitPattern.exec(source))) {
    const direction = match[1].trim().toLowerCase();
    const target = normalizeRoomId(match[2]);
    if (!target || exits.some(exit => exit.direction === direction && exit.target === target)) continue;
    exits.push({ direction, target });
  }
  const decodedName = decodePikeString(nameMatch ? nameMatch[1] : '');
  const room = {
    id,
    name: decodedName || path.basename(id),
    description: decodePikeString(descriptionMatch ? descriptionMatch[1] : ''),
    region: id.split('/')[0] || 'world',
    level: levelMatch ? Number(levelMatch[1]) : 0,
    exits
  };
  room.biome = inferBiome(room);
  return room;
}

function findFreeCoordinate(desiredX, desiredY, occupied) {
  const key = desiredX + ',' + desiredY;
  if (!occupied.has(key)) return [desiredX, desiredY];
  for (let radius = 1; radius <= 18; radius += 1) {
    for (let dx = -radius; dx <= radius; dx += 1) {
      for (const dy of [-radius, radius]) {
        const candidate = (desiredX + dx) + ',' + (desiredY + dy);
        if (!occupied.has(candidate)) return [desiredX + dx, desiredY + dy];
      }
    }
    for (let dy = -radius + 1; dy < radius; dy += 1) {
      for (const dx of [-radius, radius]) {
        const candidate = (desiredX + dx) + ',' + (desiredY + dy);
        if (!occupied.has(candidate)) return [desiredX + dx, desiredY + dy];
      }
    }
  }
  return [desiredX + occupied.size + 1, desiredY];
}

function layoutRegion(regionRooms, roomById) {
  const roomIds = regionRooms.map(room => room.id).sort();
  const roomIdSet = new Set(roomIds);
  const neighbors = new Map(roomIds.map(id => [id, []]));
  for (const room of regionRooms) {
    for (const exit of room.exits) {
      if (!roomIdSet.has(exit.target)) continue;
      const vector = DIRECTION_VECTORS[exit.direction] || [1, 0];
      neighbors.get(room.id).push({ target: exit.target, vector });
      neighbors.get(exit.target).push({ target: room.id, vector: [-vector[0], -vector[1]] });
    }
  }

  const degree = id => neighbors.get(id).length;
  const preferred = roomIds.find(id => path.basename(id) === regionRooms[0].region) ||
    roomIds.slice().sort((a, b) => degree(b) - degree(a) || a.localeCompare(b))[0];
  const seedOrder = [preferred, ...roomIds.filter(id => id !== preferred)];
  const positions = new Map();
  const occupied = new Map();
  let componentStartX = 0;

  for (const seed of seedOrder) {
    if (positions.has(seed)) continue;
    const start = findFreeCoordinate(componentStartX, 0, occupied);
    positions.set(seed, { x: start[0], y: start[1] });
    occupied.set(start[0] + ',' + start[1], seed);
    const queue = [seed];
    while (queue.length) {
      const currentId = queue.shift();
      const current = positions.get(currentId);
      for (const edge of neighbors.get(currentId)) {
        if (positions.has(edge.target)) continue;
        const desiredX = current.x + edge.vector[0];
        const desiredY = current.y + edge.vector[1];
        const free = findFreeCoordinate(desiredX, desiredY, occupied);
        positions.set(edge.target, { x: free[0], y: free[1] });
        occupied.set(free[0] + ',' + free[1], edge.target);
        queue.push(edge.target);
      }
    }
    componentStartX = Math.max(...Array.from(positions.values()).map(point => point.x)) + 3;
  }

  const values = Array.from(positions.values());
  const minX = Math.min(...values.map(point => point.x));
  const maxX = Math.max(...values.map(point => point.x));
  const minY = Math.min(...values.map(point => point.y));
  const maxY = Math.max(...values.map(point => point.y));
  const anchor = roomById.get(preferred);
  return {
    id: regionRooms[0].region,
    label: (anchor && anchor.name) || regionRooms[0].region,
    positions,
    minX,
    maxX,
    minY,
    maxY,
    width: Math.max(360, (maxX - minX + 1) * 96 + 176),
    height: Math.max(280, (maxY - minY + 1) * 96 + 176),
    nodeCount: regionRooms.length
  };
}

function buildWorldMap(roomRoot) {
  const rooms = walkFiles(roomRoot)
    .map(filePath => parseRoomFile(filePath, roomRoot))
    .filter(Boolean)
    .sort((a, b) => a.id.localeCompare(b.id));
  const roomById = new Map(rooms.map(room => [room.id, room]));
  let unresolvedExits = 0;
  for (const room of rooms) {
    room.exits = room.exits.filter(exit => {
      const resolved = roomById.has(exit.target);
      if (!resolved) unresolvedExits += 1;
      return resolved;
    });
  }

  const roomsByRegion = new Map();
  for (const room of rooms) {
    if (!roomsByRegion.has(room.region)) roomsByRegion.set(room.region, []);
    roomsByRegion.get(room.region).push(room);
  }
  const layouts = Array.from(roomsByRegion.values())
    .map(regionRooms => layoutRegion(regionRooms, roomById))
    .sort((a, b) => b.nodeCount - a.nodeCount || a.id.localeCompare(b.id));

  const totalRegionArea = layouts.reduce(
    (sum, region) => sum + (region.width + 120) * (region.height + 120), 0
  );
  // 接近宽屏世界地图的2:1比例，避免按固定窄列把完整世界拉成超长卷轴。
  const maxRowWidth = Math.max(
    4200,
    Math.ceil(Math.sqrt(totalRegionArea * 2) / 500) * 500
  );
  let cursorX = 96;
  let cursorY = 96;
  let rowHeight = 0;
  for (const region of layouts) {
    if (cursorX > 96 && cursorX + region.width > maxRowWidth) {
      cursorX = 96;
      cursorY += rowHeight + 120;
      rowHeight = 0;
    }
    region.x = cursorX;
    region.y = cursorY;
    cursorX += region.width + 120;
    rowHeight = Math.max(rowHeight, region.height);
  }

  const layoutByRegion = new Map(layouts.map(region => [region.id, region]));
  const nodes = rooms.map(room => {
    const region = layoutByRegion.get(room.region);
    const local = region.positions.get(room.id);
    return {
      id: room.id,
      name: room.name,
      region: room.region,
      biome: room.biome,
      level: room.level,
      x: Math.round(region.x + 88 + (local.x - region.minX) * 96),
      y: Math.round(region.y + 88 + (local.y - region.minY) * 96),
      exits: room.exits
    };
  });
  const nodeById = new Map(nodes.map(node => [node.id, node]));
  const edgeKeys = new Set();
  const edges = [];
  for (const node of nodes) {
    for (const exit of node.exits) {
      if (!nodeById.has(exit.target)) continue;
      const key = [node.id, exit.target].sort().join('|');
      if (edgeKeys.has(key)) continue;
      edgeKeys.add(key);
      edges.push({ from: node.id, to: exit.target });
    }
  }
  const regions = layouts.map(region => ({
    id: region.id,
    label: region.label,
    x: region.x,
    y: region.y,
    width: region.width,
    height: region.height,
    nodeCount: region.nodeCount
  }));
  const width = Math.max(...regions.map(region => region.x + region.width), 1280) + 96;
  const height = Math.max(...regions.map(region => region.y + region.height), 720) + 96;
  const contentHash = crypto.createHash('sha256')
    .update(JSON.stringify({ nodes, edges, regions, width, height }))
    .digest('hex')
    .slice(0, 16);
  return {
    schema: 1,
    version: contentHash,
    roomCount: nodes.length,
    edgeCount: edges.length,
    regionCount: regions.length,
    unresolvedExitCount: unresolvedExits,
    bounds: { width, height },
    nodes,
    edges,
    regions
  };
}

function writeWorldMap(roomRoot, outputPath) {
  const worldMap = buildWorldMap(roomRoot);
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(worldMap) + '\n');
  return worldMap;
}

if (require.main === module) {
  const projectRoot = path.resolve(__dirname, '..', '..');
  const roomRoot = path.resolve(process.argv[2] || path.join(projectRoot, 'gamelib', 'd'));
  const outputPath = path.resolve(process.argv[3] || path.join(projectRoot, 'vue_source', 'data', 'world-map.json'));
  const worldMap = writeWorldMap(roomRoot, outputPath);
  console.log('[world-map] rooms=' + worldMap.roomCount +
    ' edges=' + worldMap.edgeCount +
    ' regions=' + worldMap.regionCount +
    ' unresolved=' + worldMap.unresolvedExitCount +
    ' version=' + worldMap.version);
}

module.exports = {
  buildWorldMap,
  inferBiome,
  normalizeRoomId,
  parseRoomFile,
  writeWorldMap
};
