-- 1) Items
insert into items (code, name, category) values
  -- pastries
  ('PASTRY_SPRINGROLL',    'Springrolls',     'pastry'),
  ('PASTRY_MEATPIE',       'Meatpie',         'pastry'),
  ('PASTRY_PANCAKE',       'Pancake',         'pastry'),
  ('PASTRY_CHOCOLATE_PIE', 'Chocolate Pie',   'pastry'),
  ('PASTRY_SAUSAGE_BREAD', 'Sausage Bread',   'pastry'),
  ('PASTRY_MEATBREAD',     'Meatbread',       'pastry'),
  ('PASTRY_MEAT',          'Meat',            'pastry'),
  ('PASTRY_DOUGHNUT',      'Doughnut',        'pastry'),
  ('PASTRY_GRANOLA_BIG',   'Granola Big',     'pastry'),
  ('PASTRY_GRANOLA_SMALL', 'Granola',         'pastry'),

  -- yoghurt containers
  ('YOG_1_2L_GALLON',      '1.2L Gallon',     'yoghurt_container'),
  ('YOG_2_2L_GALLON',      '2.2L Gallon',     'yoghurt_container'),
  ('YOG_4_6L_GALLON',      '4.6L Gallon',     'yoghurt_container'),
  ('YOG_0_30L_CUP',        '0.30L Cup',       'yoghurt_container'),
  ('YOG_0_42L_CUP',        '0.42L Cup',       'yoghurt_container'),
  ('YOG_350ML_BOTTLE',     '350ml Bottle',    'yoghurt_container'),
  ('YOG_500ML_BOTTLE',     '500ml Bottle',    'yoghurt_container'),

  -- yoghurt refill
  ('YOG_REFILL_1_2L_GALLON','1.2L Gallon Refill','yoghurt_refill'),
  ('YOG_REFILL_2_2L_GALLON','2.2L Gallon Refill','yoghurt_refill'),
  ('YOG_REFILL_4_6L_GALLON','4.6L Gallon Refill','yoghurt_refill'),

  -- section B
  ('YOG_SMOOTHIE',         'Smoothies',       'smoothie'),
  ('YOG_WATER',            'Water',           'water');

-- 2) Item versions (current prices, effective today)
insert into item_versions (item_id, volume_factor, unit_price, effective_from)
select i.id,
       case
         when i.code = 'YOG_1_2L_GALLON'       then 1.2
         when i.code = 'YOG_2_2L_GALLON'       then 2.2
         when i.code = 'YOG_4_6L_GALLON'       then 4.6
         when i.code = 'YOG_0_30L_CUP'         then 0.30
         when i.code = 'YOG_0_42L_CUP'         then 0.42
         when i.code = 'YOG_350ML_BOTTLE'      then 0.35
         when i.code = 'YOG_500ML_BOTTLE'      then 0.50
         else 1
       end as volume_factor,
       case
         -- pastries
         when i.code = 'PASTRY_SPRINGROLL'     then 5
         when i.code = 'PASTRY_MEATPIE'        then 10
         when i.code = 'PASTRY_PANCAKE'        then 5
         when i.code = 'PASTRY_CHOCOLATE_PIE'  then 10
         when i.code = 'PASTRY_SAUSAGE_BREAD'  then 10
         when i.code = 'PASTRY_MEATBREAD'      then 10
         when i.code = 'PASTRY_MEAT'           then 20
         when i.code = 'PASTRY_DOUGHNUT'       then 7
         when i.code = 'PASTRY_GRANOLA_BIG'    then 85
         when i.code = 'PASTRY_GRANOLA_SMALL'  then 25

         -- yoghurt containers
         when i.code = 'YOG_1_2L_GALLON'       then 35
         when i.code = 'YOG_2_2L_GALLON'       then 60
         when i.code = 'YOG_4_6L_GALLON'       then 105
         when i.code = 'YOG_0_30L_CUP'         then 10
         when i.code = 'YOG_0_42L_CUP'         then 15
         when i.code = 'YOG_350ML_BOTTLE'      then 12
         when i.code = 'YOG_500ML_BOTTLE'      then 18

         -- refill
         when i.code = 'YOG_REFILL_1_2L_GALLON' then 30
         when i.code = 'YOG_REFILL_2_2L_GALLON' then 55
         when i.code = 'YOG_REFILL_4_6L_GALLON' then 100

         -- section B
         when i.code = 'YOG_SMOOTHIE'          then 30
         when i.code = 'YOG_WATER'             then 3
       end as unit_price,
       current_date
from items i;

-- 1) Material items
insert into items (code, name, category) values
  ('MAT_REGULAR_CUPS',  'Regular Cups',  'material'),
  ('MAT_LARGE_CUPS',    'Large Cups',    'material'),
  ('MAT_1_2L_GALLON',   '1.2L Gallons',  'material'),
  ('MAT_2_2L_GALLON',   '2.2L Gallons',  'material'),
  ('MAT_4_6L_GALLON',   '4.6L Gallons',  'material'),
  ('MAT_350ML_BOTTLE',  '350ml Bottle',  'material'),
  ('MAT_500ML_BOTTLE',  '500ml Bottle',  'material'),
  ('MAT_WATER',         'Water',         'material');

-- 2) Item versions for materials (no pricing used in sheet, so unit_price = 0)
insert into item_versions (item_id, volume_factor, unit_price, effective_from)
select i.id,
       1 as volume_factor,
       0 as unit_price,
       current_date
from items i
where i.code in (
  'MAT_REGULAR_CUPS',
  'MAT_LARGE_CUPS',
  'MAT_1_2L_GALLON',
  'MAT_2_2L_GALLON',
  'MAT_4_6L_GALLON',
  'MAT_350ML_BOTTLE',
  'MAT_500ML_BOTTLE',
  'MAT_WATER'
);