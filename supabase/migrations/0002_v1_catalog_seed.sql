-- 0002_v1_catalog_seed.sql
-- Expands the initial catalog to the v1 goods/building set.
-- Keeps unlock data inside build_rules for now to avoid adding new schema too early.

insert into public.resource_types (key, name, category, base_value)
values
  ('timber', 'Timber', 'raw', 10),
  ('stone', 'Stone', 'raw', 12),
  ('grain', 'Grain', 'raw', 8),
  ('clay', 'Clay', 'raw', 9),
  ('iron_ore', 'Iron Ore', 'raw', 14),
  ('wood_planks', 'Wood Planks', 'construction', 22),
  ('cut_stone', 'Cut Stone', 'construction', 24),
  ('bricks', 'Bricks', 'construction', 20),
  ('iron_bars', 'Iron Bars', 'construction', 28),
  ('flour', 'Flour', 'food', 18),
  ('bread', 'Bread', 'food', 24),
  ('tools', 'Tools', 'industrial', 36),
  ('pottery', 'Pottery', 'utility', 30),
  ('furniture', 'Furniture', 'prestige', 44),
  ('fine_goods', 'Fine Goods', 'prestige', 60)
on conflict (key) do update
set
  name = excluded.name,
  category = excluded.category,
  base_value = excluded.base_value,
  is_active = true;

insert into public.building_types (key, name, category, footprint_w, footprint_h, cost_gold, maintenance_gold, required_resource_key, output_resource_key, build_rules)
values
  (
    'road', 'Road', 'infrastructure', 1, 1, 5, 0, null, null,
    '{"startingUnlocked": true, "placeOn": ["buildable"], "requiresRoadAccess": false}'::jsonb
  ),
  (
    'housing_1', 'Housing I', 'housing', 1, 1, 80, 0, null, null,
    '{"startingUnlocked": true, "buildCosts": {"gold": 80, "wood_planks": 2}, "populationCap": 6, "districtTierRequired": 1}'::jsonb
  ),
  (
    'housing_2', 'Housing II', 'housing', 1, 1, 140, 1, null, null,
    '{"startingUnlocked": false, "buildCosts": {"gold": 140, "wood_planks": 3, "bricks": 2}, "populationCap": 12, "districtTierRequired": 2}'::jsonb
  ),
  (
    'housing_3', 'Upper Housing', 'housing', 1, 1, 240, 2, null, null,
    '{"startingUnlocked": false, "buildCosts": {"gold": 240, "furniture": 2, "pottery": 2, "bread": 2}, "populationCap": 18, "districtTierRequired": 3}'::jsonb
  ),
  (
    'lumber_camp', 'Lumber Camp', 'extraction', 1, 1, 100, 1, 'timber', 'timber',
    '{"startingUnlocked": true, "buildCosts": {"gold": 100}, "mustMatchResource": true, "requiresRoadAccess": true, "specialization": "timber", "districtTierRequired": 1}'::jsonb
  ),
  (
    'quarry', 'Quarry', 'extraction', 1, 1, 100, 1, 'stone', 'stone',
    '{"startingUnlocked": true, "buildCosts": {"gold": 100}, "mustMatchResource": true, "requiresRoadAccess": true, "specialization": "stone", "districtTierRequired": 1}'::jsonb
  ),
  (
    'grain_farm', 'Grain Farm', 'extraction', 1, 1, 100, 1, 'grain', 'grain',
    '{"startingUnlocked": true, "buildCosts": {"gold": 100}, "mustMatchResource": true, "requiresRoadAccess": true, "specialization": "grain", "districtTierRequired": 1}'::jsonb
  ),
  (
    'clay_pit', 'Clay Pit', 'extraction', 1, 1, 100, 1, 'clay', 'clay',
    '{"startingUnlocked": true, "buildCosts": {"gold": 100}, "mustMatchResource": true, "requiresRoadAccess": true, "specialization": "clay", "districtTierRequired": 1}'::jsonb
  ),
  (
    'iron_mine', 'Iron Mine', 'extraction', 1, 1, 110, 1, 'iron_ore', 'iron_ore',
    '{"startingUnlocked": true, "buildCosts": {"gold": 110}, "mustMatchResource": true, "requiresRoadAccess": true, "specialization": "iron", "districtTierRequired": 1}'::jsonb
  ),
  (
    'sawmill', 'Sawmill', 'refining', 1, 1, 120, 1, 'timber', 'wood_planks',
    '{"startingUnlocked": true, "buildCosts": {"gold": 120, "timber": 2}, "consumes": {"timber": 1}, "requiresRoadAccess": true, "specialization": "timber", "districtTierRequired": 1}'::jsonb
  ),
  (
    'mason_yard', 'Mason Yard', 'refining', 1, 1, 120, 1, 'stone', 'cut_stone',
    '{"startingUnlocked": true, "buildCosts": {"gold": 120, "stone": 2}, "consumes": {"stone": 1}, "requiresRoadAccess": true, "specialization": "stone", "districtTierRequired": 1}'::jsonb
  ),
  (
    'mill', 'Mill', 'refining', 1, 1, 120, 1, 'grain', 'flour',
    '{"startingUnlocked": true, "buildCosts": {"gold": 120, "grain": 2}, "consumes": {"grain": 1}, "requiresRoadAccess": true, "specialization": "grain", "districtTierRequired": 1}'::jsonb
  ),
  (
    'kiln_yard', 'Kiln Yard', 'refining', 1, 1, 120, 1, 'clay', 'bricks',
    '{"startingUnlocked": true, "buildCosts": {"gold": 120, "clay": 2}, "consumes": {"clay": 1}, "requiresRoadAccess": true, "specialization": "clay", "districtTierRequired": 1}'::jsonb
  ),
  (
    'smelter', 'Smelter', 'refining', 1, 1, 140, 1, 'iron_ore', 'iron_bars',
    '{"startingUnlocked": true, "buildCosts": {"gold": 140, "iron_ore": 2}, "consumes": {"iron_ore": 1}, "requiresRoadAccess": true, "specialization": "iron", "districtTierRequired": 1}'::jsonb
  ),
  (
    'bakery', 'Bakery', 'production', 1, 1, 160, 2, 'flour', 'bread',
    '{"startingUnlocked": false, "buildCosts": {"gold": 160, "wood_planks": 2, "bricks": 1}, "consumes": {"flour": 1}, "requiresRoadAccess": true, "districtTierRequired": 2}'::jsonb
  ),
  (
    'pottery_works', 'Pottery Works', 'production', 1, 1, 170, 2, 'clay', 'pottery',
    '{"startingUnlocked": false, "buildCosts": {"gold": 170, "bricks": 2, "clay": 2}, "consumes": {"clay": 1}, "requiresRoadAccess": true, "districtTierRequired": 2}'::jsonb
  ),
  (
    'forge_works', 'Forge Works', 'production', 1, 1, 180, 2, 'iron_bars', 'tools',
    '{"startingUnlocked": false, "buildCosts": {"gold": 180, "iron_bars": 2, "bricks": 1}, "consumes": {"iron_bars": 1}, "requiresRoadAccess": true, "districtTierRequired": 2}'::jsonb
  ),
  (
    'carpentry_works', 'Carpentry Works', 'production', 1, 1, 180, 2, 'wood_planks', 'furniture',
    '{"startingUnlocked": false, "buildCosts": {"gold": 180, "wood_planks": 2, "tools": 1}, "consumes": {"wood_planks": 1}, "requiresRoadAccess": true, "districtTierRequired": 2}'::jsonb
  ),
  (
    'artisan_studio', 'Artisan Studio', 'production', 2, 2, 260, 3, 'cut_stone', 'fine_goods',
    '{"startingUnlocked": false, "buildCosts": {"gold": 260, "cut_stone": 3, "furniture": 1, "pottery": 1}, "consumes": {"cut_stone": 1}, "requiresRoadAccess": true, "districtTierRequired": 3}'::jsonb
  ),
  (
    'warehouse', 'Warehouse', 'storage', 1, 1, 150, 1, null, null,
    '{"startingUnlocked": true, "buildCosts": {"gold": 150, "wood_planks": 2, "bricks": 1}, "storageBonus": 100, "districtTierRequired": 1}'::jsonb
  ),
  (
    'market', 'Market', 'trade', 1, 1, 170, 1, null, null,
    '{"startingUnlocked": false, "buildCosts": {"gold": 170, "wood_planks": 2, "pottery": 1}, "housingSupport": true, "districtTierRequired": 2}'::jsonb
  ),
  (
    'trade_depot', 'Trade Depot', 'trade', 2, 1, 220, 2, null, null,
    '{"startingUnlocked": true, "buildCosts": {"gold": 220, "cut_stone": 2, "iron_bars": 1, "pottery": 1}, "tradeSlots": 2, "externalTradeEnabled": true, "districtTierRequired": 1}'::jsonb
  ),
  (
    'district_hall', 'District Hall', 'civic', 2, 2, 240, 2, null, null,
    '{"startingUnlocked": true, "buildCosts": {"gold": 240, "cut_stone": 2, "furniture": 1}, "districtTierRequired": 1, "upgradesDistrictTierTo": 2}'::jsonb
  ),
  (
    'civic_center_upgrade', 'Civic Center Upgrade', 'civic', 2, 2, 320, 3, null, null,
    '{"startingUnlocked": false, "buildCosts": {"gold": 320, "cut_stone": 3, "furniture": 2, "fine_goods": 1}, "districtTierRequired": 2, "upgradesDistrictTierTo": 3}'::jsonb
  )
on conflict (key) do update
set
  name = excluded.name,
  category = excluded.category,
  footprint_w = excluded.footprint_w,
  footprint_h = excluded.footprint_h,
  cost_gold = excluded.cost_gold,
  maintenance_gold = excluded.maintenance_gold,
  required_resource_key = excluded.required_resource_key,
  output_resource_key = excluded.output_resource_key,
  build_rules = excluded.build_rules,
  is_active = true;
