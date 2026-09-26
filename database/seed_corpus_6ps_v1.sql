-- ==========================================================
-- 6ps 蔬菜病虫害语料入库 v1（作物 + 病虫害 + 图片）
-- 生成脚本: scripts/import_corpus.py（请勿手工编辑，改映射表后重新生成）
-- 映射来源: dataset/corpus_mapping.json v1.0
-- 语料来源: raw_materials/6ps （49 张图 / 12 个分类）
-- 生成时间: 2026-09-26T08:57:26+08:00
--
-- 入库状态约定（重要）:
--   * 新增病虫害一律 approval_status='draft' + is_active=FALSE
--     → 内容未补全前不会出现在用户端知识库，补全并经专家审核后再激活
--   * 新增图片一律 label_status='ai_only' + approval_status='pending'
--     → 文件名只是弱标签，必须经专家确认才可进入训练集
--   * name_lo 全部留空：语料只有中文，老挝语译名需老挝语专家校核后填写
--
-- 幂等性: 全部 INSERT 均带 WHERE NOT EXISTS，可重复执行
-- 回滚: 见文件末尾 ROLLBACK 段落（注释形式，需手工执行）
-- ==========================================================


-- ==========================================================
-- 1. 新增作物分类
-- ==========================================================
INSERT INTO core.crop_category (version, name_zh, name_en, sort_order)
SELECT 'vegetable', '根菜类', 'Root Vegetables', 4
WHERE NOT EXISTS (SELECT 1 FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '根菜类');


-- ==========================================================
-- 2. 新增作物
-- name_lo 留空：语料为中文，老挝语译名需专家校核后补充
-- ==========================================================
INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,
    description_zh, planting_info_zh)
SELECT 'vegetable',
       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '叶菜类' LIMIT 1),
       '西兰花', 'Broccoli', 'Brassica oleracea var. italica',
       '西兰花属十字花科，喜冷凉气候，适宜温度15-22°C，老挝北部高海拔地区可种植，苗期易发生立枯病。',
       '播种期: 10-2月(北部高地) / 育苗移栽 / 株距40×50cm / 生长期90-120天'
WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = '西兰花');

INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,
    description_zh, planting_info_zh)
SELECT 'vegetable',
       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '叶菜类' LIMIT 1),
       '甘蓝', 'Cabbage', 'Brassica oleracea var. capitata',
       '甘蓝（卷心菜）喜冷凉湿润，适宜温度15-20°C，老挝北部山区主栽蔬菜之一，霜霉病为主要叶部病害。',
       '播种期: 10-1月(北部) / 育苗移栽 / 株距40×40cm / 生长期80-120天'
WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = '甘蓝');

INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,
    description_zh, planting_info_zh)
SELECT 'vegetable',
       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '叶菜类' LIMIT 1),
       '芥菜', 'Leaf Mustard', 'Brassica juncea',
       '芥菜喜温暖湿润，适应性强，老挝全年可种植，雨季软腐病发生较重。',
       '播种期: 全年 / 直播或育苗移栽 / 株距25×30cm / 生长期45-70天'
WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = '芥菜');

INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,
    description_zh, planting_info_zh)
SELECT 'vegetable',
       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '根菜类' LIMIT 1),
       '萝卜', 'Radish', 'Raphanus sativus',
       '萝卜为十字花科根菜，喜冷凉气候，适宜温度15-20°C，生长期短，是病毒病与黄曲条跳甲的常见寄主。',
       '播种期: 10-2月 / 直播 / 株距20×30cm / 生长期50-80天'
WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = '萝卜');

INSERT INTO core.crop (version, category_id, name_zh, name_en, scientific_name,
    description_zh, planting_info_zh)
SELECT 'vegetable',
       (SELECT id FROM core.crop_category WHERE version = 'vegetable' AND name_zh = '瓜类' LIMIT 1),
       '南瓜', 'Pumpkin', 'Cucurbita moschata',
       '南瓜耐热耐旱，适应性强，老挝全年可种植，白粉病与病毒病为主要病害。',
       '播种期: 全年 / 直播 / 株距80×150cm / 生长期90-120天 / 需搭架或压蔓'
WHERE NOT EXISTS (SELECT 1 FROM core.crop WHERE name_zh = '南瓜');


-- ==========================================================
-- 3. 新增病虫害（草案状态）
-- approval_status='draft' + is_active=FALSE → 内容补全前不进用户端
-- symptoms/conditions 留空：需农业专家依据语料图片填写
-- ==========================================================

-- 语料类别: 蔬菜猝倒、立枯病（任务1（1蔬菜猝倒、立枯病））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       '辣椒猝倒病', 'Damping-off of Chili', 'Pythium spp.',
       'disease', 'severe', '猝倒,苗期,茎基腐,土传,真菌,卵菌,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '辣椒猝倒病');

INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '西兰花' LIMIT 1),
       '西兰花立枯病', 'Rhizoctonia Damping-off of Broccoli', 'Rhizoctonia solani',
       'disease', 'severe', '立枯,苗期,茎基腐,土传,真菌,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '西兰花立枯病');


-- 语料类别: 蔬菜霜霉病（任务1（2蔬菜霜霉病））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       '白菜霜霉病', 'Downy Mildew of Chinese Cabbage', 'Hyaloperonospora brassicae',
       'disease', 'severe', '霜霉,叶斑,叶背霉层,卵菌,高湿,十字花科', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '白菜霜霉病');

INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '甘蓝' LIMIT 1),
       '甘蓝霜霉病', 'Downy Mildew of Cabbage', 'Hyaloperonospora brassicae',
       'disease', 'moderate', '霜霉,叶斑,叶背霉层,卵菌,高湿,十字花科', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '甘蓝霜霉病');


-- 语料类别: 瓜类白粉病（任务1（3瓜类白粉病））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       '南瓜白粉病', 'Powdery Mildew of Pumpkin', 'Podosphaera xanthii',
       'disease', 'moderate', '白粉,叶面白粉,真菌,干燥高湿交替,瓜类,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '南瓜白粉病');


-- 语料类别: 白菜软腐病（任务1（4白菜软腐病））
-- [复用已有条目] 白菜软腐病
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '芥菜' LIMIT 1),
       '芥菜软腐病', 'Bacterial Soft Rot of Leaf Mustard', 'Pectobacterium carotovorum',
       'disease', 'severe', '软腐,细菌,根茎腐烂,高湿,连作,伤口侵染', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '芥菜软腐病');


-- 语料类别: 茄科蔬菜青枯病（任务1（5茄科蔬菜青枯病））
-- [复用已有条目] 番茄青枯病

-- 语料类别: 蔬菜病毒病（任务1（6蔬菜病毒病））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       '番茄病毒病', 'Tomato Viral Disease', 'Tomato mosaic virus / Cucumber mosaic virus complex',
       'disease', 'severe', '病毒,花叶,皱缩,畸形,蚜虫传播,无药剂可治', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '番茄病毒病');

INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       '萝卜病毒病', 'Radish Viral Disease', 'Turnip mosaic virus',
       'disease', 'moderate', '病毒,花叶,矮化,蚜虫传播,十字花科,无药剂可治', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '萝卜病毒病');

INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       '南瓜病毒病', 'Pumpkin Viral Disease', 'Cucumber mosaic virus / Zucchini yellow mosaic virus',
       'disease', 'severe', '病毒,花叶,蕨叶,畸形,蚜虫传播,瓜类,无药剂可治', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '南瓜病毒病');


-- 语料类别: 蔬菜根结线虫病（任务1（7蔬菜根结线虫病））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       '番茄根结线虫病', 'Root-knot Nematode of Tomato', 'Meloidogyne incognita',
       'disease', 'severe', '根结线虫,根部瘤状,土传,连作,沙壤土', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '番茄根结线虫病');


-- 语料类别: 菜粉蝶（任务2（1菜粉蝶））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       '菜粉蝶(白菜)', 'Cabbage White Butterfly on Chinese Cabbage', 'Pieris rapae',
       'pest', 'moderate', '菜青虫,咀嚼式口器,叶穿孔,鳞翅目,十字花科,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '菜粉蝶(白菜)');


-- 语料类别: 小菜蛾（任务2（2小菜蛾））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       '小菜蛾(白菜)', 'Diamondback Moth on Chinese Cabbage', 'Plutella xylostella',
       'pest', 'severe', '小菜蛾,钻食,窗孔状,鳞翅目,十字花科,抗药性强,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '小菜蛾(白菜)');


-- 语料类别: 黄曲条跳甲（任务2（3黄曲条跳甲））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       '黄曲条跳甲(萝卜)', 'Striped Flea Beetle on Radish', 'Phyllotreta striolata',
       'pest', 'severe', '跳甲,苗期毁苗,叶面小孔,根部咬痕,鞘翅目,十字花科,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)');


-- 语料类别: 温室白粉虱（任务2（4温室白粉虱））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '黄瓜' LIMIT 1),
       '温室白粉虱(黄瓜)', 'Greenhouse Whitefly on Cucumber', 'Trialeurodes vaporariorum',
       'pest', 'moderate', '白粉虱,叶背密集,蜜露,烟霉,病毒媒介,大棚,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '温室白粉虱(黄瓜)');


-- 语料类别: 侧多食跗线螨（任务2（5侧多食跗线螨））
INSERT INTO core.disease (version, crop_id, name_zh, name_en, scientific_name,
    type, severity_level, tags, source_type, approval_status, is_active)
SELECT 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       '侧多食跗线螨(辣椒)', 'Broad Mite on Chili', 'Polyphagotarsonemus latus',
       'pest', 'moderate', '跗线螨,嫩叶畸形,叶背褐变,高温干燥,跨作物', 'TEACHER_DATA', 'draft', FALSE
WHERE NOT EXISTS (SELECT 1 FROM core.disease WHERE name_zh = '侧多食跗线螨(辣椒)');


-- ==========================================================
-- 4. 语料图片入库（弱标注，待专家确认）
-- ==========================================================

-- 任务1（1蔬菜猝倒、立枯病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（1蔬菜猝倒、立枯病）/1辣椒-腐霉菌属引起的猝倒病.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '辣椒猝倒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'stem', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（1蔬菜猝倒、立枯病）/1辣椒-腐霉菌属引起的猝倒病.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（1蔬菜猝倒、立枯病）/2西兰花幼苗立枯病.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '西兰花' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '西兰花立枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'stem', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（1蔬菜猝倒、立枯病）/2西兰花幼苗立枯病.jpg');


-- 任务1（2蔬菜霜霉病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（2蔬菜霜霉病）/1大白菜叶子霜霉病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '白菜霜霉病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（2蔬菜霜霉病）/1大白菜叶子霜霉病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（2蔬菜霜霉病）/2卷心菜叶子霜霉病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '甘蓝' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '甘蓝霜霉病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（2蔬菜霜霉病）/2卷心菜叶子霜霉病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（2蔬菜霜霉病）/3卷心菜叶子霜霉病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '甘蓝' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '甘蓝霜霉病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（2蔬菜霜霉病）/3卷心菜叶子霜霉病症状.jpg');


-- 任务1（3瓜类白粉病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（3瓜类白粉病）/1南瓜白粉病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '南瓜白粉病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（3瓜类白粉病）/1南瓜白粉病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（3瓜类白粉病）/2南瓜白粉病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '南瓜白粉病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（3瓜类白粉病）/2南瓜白粉病症状.jpg');


-- 任务1（4白菜软腐病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（4白菜软腐病）/1白菜软腐病症状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '白菜软腐病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（4白菜软腐病）/1白菜软腐病症状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（4白菜软腐病）/2白菜软腐病症状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '白菜软腐病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（4白菜软腐病）/2白菜软腐病症状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（4白菜软腐病）/3芥菜软腐病症状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '芥菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '芥菜软腐病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（4白菜软腐病）/3芥菜软腐病症状.JPG');


-- 任务1（5茄科蔬菜青枯病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/1番茄细菌性青枯病的严重症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄青枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/1番茄细菌性青枯病的严重症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/2番茄细菌性青枯病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄青枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/2番茄细菌性青枯病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/3大面积严重感染青枯病的番茄植株.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄青枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/3大面积严重感染青枯病的番茄植株.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/4青枯病感染后番茄维管束系统变暗.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄青枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/4青枯病感染后番茄维管束系统变暗.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/5青枯病感染后的番茄茎秆渗出的菌脓.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄青枯病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'whole', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（5茄科蔬菜青枯病）/5青枯病感染后的番茄茎秆渗出的菌脓.jpg');


-- 任务1（6蔬菜病毒病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/1番茄病毒病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/1番茄病毒病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/2番茄病毒病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/2番茄病毒病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/3萝卜病毒病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '萝卜病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/3萝卜病毒病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/4萝卜病毒病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '萝卜病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/4萝卜病毒病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/5南瓜病毒病症状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '南瓜病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/5南瓜病毒病症状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（6蔬菜病毒病）/6南瓜病毒病症状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '南瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '南瓜病毒病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（6蔬菜病毒病）/6南瓜病毒病症状.JPG');


-- 任务1（7蔬菜根结线虫病）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/1番茄根结线虫病症状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄根结线虫病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'root', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/1番茄根结线虫病症状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/2健康的番茄植株（左）与被根结线虫侵染的植株（右）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄根结线虫病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'root', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/2健康的番茄植株（左）与被根结线虫侵染的植株（右）.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/3番茄根部的根结.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄根结线虫病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'root', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/3番茄根部的根结.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/4根结线虫雌成虫.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '番茄' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '番茄根结线虫病' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'root', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务1（7蔬菜根结线虫病）/4根结线虫雌成虫.jpg');


-- 任务2（1菜粉蝶）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/1菜粉蝶为害状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/1菜粉蝶为害状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/2菜粉蝶为害状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/2菜粉蝶为害状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/3菜粉蝶卵.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/3菜粉蝶卵.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/4菜粉蝶幼虫.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/4菜粉蝶幼虫.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/5菜粉蝶蛹.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/5菜粉蝶蛹.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（1菜粉蝶）/6菜粉蝶成虫.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '菜粉蝶(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（1菜粉蝶）/6菜粉蝶成虫.JPG');


-- 任务2（2小菜蛾）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（2小菜蛾）/1小菜蛾为害状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '小菜蛾(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（2小菜蛾）/1小菜蛾为害状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（2小菜蛾）/2小菜蛾幼虫.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '小菜蛾(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（2小菜蛾）/2小菜蛾幼虫.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（2小菜蛾）/3小菜蛾蛹.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '小菜蛾(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（2小菜蛾）/3小菜蛾蛹.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（2小菜蛾）/4小菜蛾成虫.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '白菜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '小菜蛾(白菜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（2小菜蛾）/4小菜蛾成虫.jpg');


-- 任务2（3黄曲条跳甲）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/1黄曲条跳甲成虫为害状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/1黄曲条跳甲成虫为害状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/2黄曲条跳甲成虫为害状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/2黄曲条跳甲成虫为害状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/3黄曲条跳甲成虫为害状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/3黄曲条跳甲成虫为害状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/4黄曲条跳甲成虫为害状.JPG', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/4黄曲条跳甲成虫为害状.JPG');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/5黄曲条跳甲成虫为害状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/5黄曲条跳甲成虫为害状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/6黄曲条跳甲幼虫为害状（引自王助引、于永浩，2016）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/6黄曲条跳甲幼虫为害状（引自王助引、于永浩，2016）.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/7黄曲条跳甲成虫（引自王助引、于永浩，2016）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/7黄曲条跳甲成虫（引自王助引、于永浩，2016）.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（3黄曲条跳甲）/8黄曲条跳甲幼虫（引自王助引、于永浩，2016）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '萝卜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '黄曲条跳甲(萝卜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（3黄曲条跳甲）/8黄曲条跳甲幼虫（引自王助引、于永浩，2016）.jpg');


-- 任务2（4温室白粉虱）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（4温室白粉虱）/1温室白粉虱为害黄瓜.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '黄瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '温室白粉虱(黄瓜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（4温室白粉虱）/1温室白粉虱为害黄瓜.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（4温室白粉虱）/2温室白粉虱为害状（引自王助引、于永浩，2016）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '黄瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '温室白粉虱(黄瓜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（4温室白粉虱）/2温室白粉虱为害状（引自王助引、于永浩，2016）.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（4温室白粉虱）/3温室白粉虱成虫和卵（引自王助引、于永浩，2016）.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '黄瓜' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '温室白粉虱(黄瓜)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（4温室白粉虱）/3温室白粉虱成虫和卵（引自王助引、于永浩，2016）.jpg');


-- 任务2（5侧多食跗线螨）
INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（5侧多食跗线螨）/1螨为害状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '侧多食跗线螨(辣椒)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（5侧多食跗线螨）/1螨为害状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（5侧多食跗线螨）/2螨为害状.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '侧多食跗线螨(辣椒)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（5侧多食跗线螨）/2螨为害状.jpg');

INSERT INTO core.disease_image (image_url, version, crop_id, disease_id, image_source,
    source_type, plant_part, label_status, approval_status, language, is_public, is_active)
SELECT 'raw_materials/6ps/任务2（5侧多食跗线螨）/3螨成虫.jpg', 'vegetable',
       (SELECT id FROM core.crop WHERE name_zh = '辣椒' LIMIT 1),
       (SELECT id FROM core.disease WHERE name_zh = '侧多食跗线螨(辣椒)' LIMIT 1),
       'TEACHER_DATA', 'TEACHER_DATA', 'leaf', 'ai_only', 'pending', 'zh', FALSE, TRUE
WHERE NOT EXISTS (SELECT 1 FROM core.disease_image WHERE image_url = 'raw_materials/6ps/任务2（5侧多食跗线螨）/3螨成虫.jpg');


-- ==========================================================
-- 5. 刷新病虫害图片计数
-- ==========================================================
UPDATE core.disease d
   SET image_count = (SELECT COUNT(*) FROM core.disease_image i
                       WHERE i.disease_id = d.id AND i.is_active = TRUE),
       updated_at = NOW()
 WHERE d.name_zh IN (
    '侧多食跗线螨(辣椒)',
    '南瓜病毒病',
    '南瓜白粉病',
    '小菜蛾(白菜)',
    '温室白粉虱(黄瓜)',
    '甘蓝霜霉病',
    '番茄根结线虫病',
    '番茄病毒病',
    '番茄青枯病',
    '白菜软腐病',
    '白菜霜霉病',
    '芥菜软腐病',
    '菜粉蝶(白菜)',
    '萝卜病毒病',
    '西兰花立枯病',
    '辣椒猝倒病',
    '黄曲条跳甲(萝卜)'
 );


-- ==========================================================
-- 6. 校验查询
-- ==========================================================
-- 预期: 图片总数为 49，新增病虫害为 15 条草稿，复用条目 2 条
SELECT c.name_zh AS 作物, d.name_zh AS 病虫害, d.approval_status, d.is_active,
       COUNT(i.id) AS 图片数
  FROM core.disease d
  JOIN core.crop c ON c.id = d.crop_id
  LEFT JOIN core.disease_image i ON i.disease_id = d.id AND i.is_active = TRUE
 WHERE d.name_zh IN (
    '侧多食跗线螨(辣椒)',
    '南瓜病毒病',
    '南瓜白粉病',
    '小菜蛾(白菜)',
    '温室白粉虱(黄瓜)',
    '甘蓝霜霉病',
    '番茄根结线虫病',
    '番茄病毒病',
    '番茄青枯病',
    '白菜软腐病',
    '白菜霜霉病',
    '芥菜软腐病',
    '菜粉蝶(白菜)',
    '萝卜病毒病',
    '西兰花立枯病',
    '辣椒猝倒病',
    '黄曲条跳甲(萝卜)'
 )
 GROUP BY c.name_zh, d.name_zh, d.approval_status, d.is_active
 ORDER BY 作物, 病虫害;


-- ==========================================================
-- ROLLBACK（需要撤销本文件入库结果时手工执行）
-- ==========================================================
-- DELETE FROM core.disease_image WHERE image_url LIKE 'raw_materials/6ps/%%';
-- DELETE FROM core.disease WHERE approval_status = 'draft' AND source_type = 'TEACHER_DATA'
--   AND name_zh IN (新增条目列表);
-- DELETE FROM core.crop WHERE name_zh IN ('西兰花','甘蓝','芥菜','萝卜','南瓜');
