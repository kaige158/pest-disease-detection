-- ==========================================
-- 田间实拍素材入库 — 华桂数农图片批次
-- 来源: 华桂数农平台现场照片 (2026-06-24 ~ 2026-06-26)
-- 识别方式: AI视觉识别 (Claude Vision) — 建议专家审核后定稿
-- 入库时间: 2026-08-15
-- 图片存放: raw_materials/images/
-- ==========================================

-- ==========================================
-- 1. 新增作物分类
-- ==========================================
INSERT INTO core.crop_category (version, name_zh, name_lo, name_en, sort_order) VALUES
('fruit',      '热带浆果',   'ໝວດໝາກນ້ຳ',         'Tropical Berries',  3),
('vegetable',  '粮经作物',   'ໝວດພືດໄຮ່',          'Staple Crops',      4);
-- 预期新 category_id: 热带浆果=6, 粮经作物=7

-- ==========================================
-- 2. 新增作物 (5种)
-- ==========================================
INSERT INTO core.crop (version, category_id, name_zh, name_lo, name_en, scientific_name,
    description_zh, description_lo, planting_info_zh) VALUES

-- 草莓 (fruit, category_id=6 热带浆果)
('fruit', 6, '草莓', 'ສະຕໍເບີຣີ', 'Strawberry', 'Fragaria × ananassa',
 '草莓适宜冷凉气候，在老挝北部高海拔地区可种植。果实红艳，是重要经济果品。',
 'ສະຕໍເບີຣີມັກອາກາດເຢັນ, ປູກໄດ້ຢູ່ທີ່ສູງທາງພາກເໜືອ.',
 '播种期: 9-11月(北部高地) / 株距25×30cm / 生长期90-120天 / 需遮阳网'),

-- 火龙果 (fruit, category_id=4 热带果树)
('fruit', 4, '火龙果', 'ໝາກສີດ', 'Dragon Fruit', 'Hylocereus undatus',
 '火龙果耐旱喜光，适宜热带亚热带气候，老挝平原地区广泛种植。',
 'ໝາກສີດທົນແລ້ງມັກແດດ, ປູກໄດ້ທົ່ວໄປໃນທົ່ງຮາບ.',
 '株距3×4m / 种植后12-18月结果 / 全年多次采收 / 需搭柱支撑'),

-- 生菜 (vegetable, category_id=3 叶菜类)
('vegetable', 3, '生菜', 'ຜັກສາລັດ', 'Lettuce', 'Lactuca sativa',
 '生菜喜冷凉，老挝旱季大棚种植为主，生长周期短，是重要叶菜。',
 'ຜັກສາລັດມັກອາກາດເຢັນ, ປູກໃນເຮືອນຕາໄຂ່ລະດູແລ້ງ.',
 '播种期: 10-2月 / 育苗移栽 / 生长期40-60天 / 株距20×25cm'),

-- 百香果 (fruit, category_id=4 热带果树)
('fruit', 4, '百香果', 'ໝາກນົມ', 'Passion Fruit', 'Passiflora edulis',
 '百香果为藤本果树，喜温暖湿润，老挝山地广泛种植，果实香气浓郁。',
 'ໝາກນົມເປັນໄມ້ເລືອຍ, ມັກອາກາດອົ່ນຊຸ່ມ, ກິ່ນຫອມ.',
 '株距2×3m / 需搭棚架 / 种植后6-8月结果 / 全年采收'),

-- 甜玉米 (vegetable, category_id=7 粮经作物)
('vegetable', 7, '甜玉米', 'ສາລີຫວານ', 'Sweet Corn', 'Zea mays var. saccharata',
 '甜玉米是重要蔬粮兼用作物，老挝全年均可种植，亦是虫害高发作物。',
 'ສາລີຫວານເປັນພືດທີ່ສຳຄັນ, ປູກໄດ້ທຸກລະດູ, ແມງໄມ້ທຳລາຍຫຼາຍ.',
 '株距25×60cm / 生长期70-90天 / 需充足水分和光照');
-- 预期新 crop_id: 草莓=9, 火龙果=10, 生菜=11, 百香果=12, 甜玉米=13

-- ==========================================
-- 3. 病虫害数据 — 来自田间实拍，AI视觉识别
-- ⚠️  source_type = 'FIELD_COLLECTION'
-- ⚠️  症状描述含 [AI识别] 标注，建议专家审核确认
-- ==========================================
INSERT INTO core.disease (version, crop_id, name_zh, name_lo, name_en, scientific_name,
    type, severity_level, symptoms_zh, symptoms_lo, conditions_zh, conditions_lo, tags, source_type) VALUES

-- ─────────────────────────────────────────
-- 草莓病虫害 (crop_id=9)
-- ─────────────────────────────────────────

-- 图片: 番茄、果类瓜类等1.jpg — 叶背白色小飞虫密集
('fruit', 9, '草莓白粉虱', 'ແມງໄມ້ຂາວຜີເສື້ອ ສະຕໍເບີຣີ', 'Whitefly on Strawberry',
 'Bemisia tabaci / Trialeurodes vaporariorum',
 'pest', 'moderate',
 '[AI识别] 叶片背面密集分布白色粉状小飞虫（体长约1mm），振动植株时大量飞起。被害叶片出现黄色小斑点，叶面失绿，严重时分泌蜜露诱发烟霉病使叶面变黑。[建议专家审核]',
 '[AI ກວດພົບ] ໃຕ້ໃບມີແມງໄມ້ຂາວຂະໜາດນ້ອຍ (~1mm) ຫຼາຍໂຕ, ສ່ຳ​ ໃຊ້ກໍ່ຈະບິນ. ໃບມີຈຸດເຫຼືອງ, ສີໃບຈາງ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度22-30°C，保护地大棚内终年可发生，干燥环境繁殖迅速。是病毒病传播媒介。',
 'ອຸນຫະພູມ 22-30°C, ໃນເຮືອນຕາໄຂ່ເກີດໄດ້ຕະຫຼອດປີ. ອາກາດແຫ້ງລ້ຽງໄວ.',
 '白粉虱,飞虱,叶背,叶黄,烟霉,病毒媒介,大棚', 'FIELD_COLLECTION'),

-- 图片: 果类瓜类9-草莓-灰霉病.jpg — 草莓果实及萼片异常
('fruit', 9, '草莓灰霉病', 'ພະຍາດໂບໄຕຣທີສ ສະຕໍເບີຣີ', 'Gray Mold on Strawberry',
 'Botrytis cinerea',
 'disease', 'severe',
 '[AI识别] 未成熟果实颜色异常（灰白/粉色），果柄及萼片出现褐色水渍状腐败；湿度大时果面及花器覆盖灰色霉层。老叶叶缘亦可见褐色枯斑。损失可达30-80%。[建议专家审核]',
 '[AI ກວດພົບ] ໝາກດິບສີຜິດປົກກະຕິ (ສີຂີ້ເທົ່າ/ບົວ), ກ້ານໝາກແລະໃບຫຸ້ມເນົ່າສີນ້ຳຕານ. ຊຸ່ມຫຼາຍຈະມີເຊື້ອສີຂີ້ເທົ່າ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度15-22°C，相对湿度>90%，多阴雨天气高发。密植、通风差条件下最严重。花期和果期最易感染。',
 'ອຸນຫະພູມ 15-22°C, ຄວາມຊຸ່ມ >90%, ເມຄຝົນຫຼາຍ. ພືດຖີ່ລົມຂ້າງບໍ່ດີ.',
 '灰霉,果腐,花腐,高湿,阴雨,真菌,Botrytis', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 火龙果病害 (crop_id=10)
-- ─────────────────────────────────────────

-- 图片: 果类瓜类5-火龙果-茎枯病.jpg — 茎干灰白腐烂斑块
('fruit', 10, '火龙果茎枯病', 'ພະຍາດລຳຕົ້ນແຫ້ງໝາກສີດ', 'Stem Blight of Dragon Fruit',
 'Neoscytalidium dimidiatum / Colletotrichum spp.',
 'disease', 'severe',
 '[AI识别] 茎节出现灰白色至浅褐色不规则腐烂斑块，病斑边缘颜色加深，病健交界清晰。病斑表面干瘪凹陷，严重时茎节整段腐烂变黑枯死，上部茎蔓萎蔫。雨季传播快，是火龙果主要毁灭性病害。[建议专家审核]',
 '[AI ກວດພົບ] ລຳຕົ້ນມີຈຸດສີຂາວເທົ່າ-ນ້ຳຕານ, ຂອບຈຸດສີເຂັ້ມ. ຈຸດຫ່ຽວຫົດ, ຮຸນແຮງລຳຕົ້ນດຳຕາຍ. ລະດູຝົນແຜ່ໄວ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度25-35°C，雨季高温高湿时爆发。机械伤口是病菌侵入主要通道。通风不良果园发病重。',
 'ອຸນຫະພູມ 25-35°C, ລະດູຝົນຮ້ອນຊຸ່ມ. ບາດແຜເຄື່ອງໃນຊ່ອງທາງຕົ້ນ. ລົມຂ້າງບໍ່ດີ.',
 '茎枯,腐烂,灰白斑,火龙果,雨季,毁灭性,真菌', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 生菜病虫害 (crop_id=11)
-- ─────────────────────────────────────────

-- 图片: 果类瓜类3-青虫病.jpg / 蔬菜3.jpg — 叶片大量缺孔
('vegetable', 11, '菜青虫(生菜)', 'ໜອນຜີເສື້ອຂາວ ຜັກສາລັດ', 'Cabbage Worm on Lettuce',
 'Pieris rapae',
 'pest', 'moderate',
 '[AI识别] 叶片呈现大量不规则圆形或椭圆形孔洞，孔洞边缘光滑，典型咀嚼式口器危害特征。幼虫浅绿色，体长约2-3cm，白天躲藏于叶片背面，夜间取食活跃。严重时全株仅剩叶脉，丧失商品性。[建议专家审核]',
 '[AI ກວດພົບ] ໃບມີຮູຮ່ອງສີ່ຫຼ່ຽມ ຫຼື ວົງ ຫຼາຍຮູ, ຂອບຮູຄ່ອຍໆ. ໜອນສີຂຽວ ~2-3cm ຊ່ອນໃຕ້ໃບ, ກິນກາງຄືນ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '全年均可发生，温度15-30°C最适宜，春秋两季高峰。密植通风差的大棚内危害重。成虫产卵于叶背。',
 'ເກີດໄດ້ຕະຫຼອດປີ, 15-30°C ເໝາະ, ລະດູໃໝ່ແລະດອກໄໝ້ຫຼົ່ນໂດດເດັ່ນ.',
 '青虫,菜青虫,孔洞,叶穿孔,鳞翅目,大棚,叶菜', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 百香果病害 (crop_id=12)
-- ─────────────────────────────────────────

-- 图片: 果类瓜类6-叶枯病.jpg — 叶片边缘焦枯、褐斑
('fruit', 12, '百香果叶枯病', 'ພະຍາດໃບໄໝ້ໝາກນົມ', 'Leaf Blight of Passion Fruit',
 'Alternaria passiflorae / Phytophthora spp.',
 'disease', 'moderate',
 '[AI识别] 叶片边缘出现不规则黄褐色焦枯斑，病斑由叶缘向内扩展；部分叶片有红褐色圆形或不规则斑点，病斑中央颜色较浅，周围有黄色晕圈。严重时叶片大面积枯焦早落，影响光合作用和产量。[建议专家审核]',
 '[AI ກວດພົບ] ຂອບໃບມີຈຸດເຫຼືອງ-ນ້ຳຕານຊ້ຳ, ຂະຫຍາຍເຂົ້າໃນໃບ. ຈຸດສີນ້ຳຕານ-ແດງ, ກາງຈຸດສີອ່ອນ, ມີວົງສີເຫຼືອງ. ຮຸນແຮງໃບຫຼົ່ນໄວ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '高温多雨（25-32°C），台风过后常大爆发。偏施氮肥、植株徒长时发病重。老叶先发病。',
 'ອາກາດຮ້ອນຝົນຕົກ (25-32°C), ຫຼັງພາຍຸ. ໃສ່ປຸ໋ຍ N ຫຼາຍ, ໃບລຸ່ມເປັນກ່ອນ.',
 '叶枯,叶缘焦枯,褐斑,真菌,雨后,百香果', 'FIELD_COLLECTION'),

-- 图片: 果类瓜类7-炭疽病.jpg — 叶片黄化带褐色圆形病斑
('fruit', 12, '百香果炭疽病', 'ພະຍາດແອນແທຣກໂນສໝາກນົມ', 'Anthracnose of Passion Fruit',
 'Colletotrichum gloeosporioides',
 'disease', 'moderate',
 '[AI识别] 叶片整体黄化失绿，散布红褐色圆形或椭圆形病斑（直径3-8mm），病斑周围有黄色晕圈。嫩叶发病率高。高湿时病斑表面出现橙红色分生孢子堆。严重时引起大量落叶落果。[建议专家审核]',
 '[AI ກວດພົບ] ໃບໂດຍລວມສີເຫຼືອງ, ມີຈຸດສີນ້ຳຕານ-ແດງຮູບວົງ (3-8mm), ວົງສີເຫຼືອງ. ໃບອ່ອນເປັນຫຼາຍ. ຊຸ່ມຫຼາຍຈະມີຝຸ່ນສ້ົມ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度24-30°C，相对湿度>85%，雨季高发。果实近成熟期最易感染造成腐烂落果。',
 'ອຸນຫະພູມ 24-30°C, ຄວາມຊຸ່ມ >85%, ລະດູຝົນ. ໝາກໃກ້ສຸກ.',
 '炭疽,圆斑,叶黄,落叶,落果,百香果,真菌', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 甜玉米病虫害 (crop_id=13)
-- ─────────────────────────────────────────

-- 图片: 蔬菜5.jpg — 玉米心叶中可见青虫，粪便明显
('vegetable', 13, '草地贪夜蛾(甜玉米)', 'ໜອນກິນໃບສາລີ (ກາໂລ ເໝາ)', 'Fall Armyworm on Sweet Corn',
 'Spodoptera frugiperda',
 'pest', 'severe',
 '[AI识别] 玉米心叶内发现绿褐色幼虫（体长约1-2cm，头部黑色），叶片出现不规则孔洞，心叶处有大量颗粒状褐色粪便（直径约1mm），为草地贪夜蛾典型危害特征。心叶被害后展开呈"花叶窗孔状"。是全球重大检疫性害虫，2019年传入老挝地区。[建议专家审核]',
 '[AI ກວດພົບ] ພົບໜອນສີຂຽວ-ນ້ຳຕານ (~1-2cm, ຫົວດຳ) ໃນໃຈສາລີ, ໃບຖືກເຈາະ, ມີຂີ້ໝາກ (1mm). ໄສ້ໃຈສາລີຕາຍ, ແຜ່ຈາກໃຈ. ເປັນແມງໄມ້ກັກກັນ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度20-30°C，雨季和旱季均可危害。成虫有强迁飞能力，可迁移数百公里。夜间产卵、幼虫夜食，防治难度大。',
 'ອຸນຫະພູມ 20-30°C, ທຸກລະດູ. ດ່ວງໂຕແກ່ບິນໄດ້ໄກ. ໜອນກິນກາງຄືນ.',
 '草地贪夜蛾,心叶,孔洞,粪便,检疫,迁飞性,玉米', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 黄瓜新增病害 (crop_id=3)
-- ─────────────────────────────────────────

-- 图片: 蔬菜1.jpg / 蔬菜2.jpg — 黄瓜幼苗病毒病
('vegetable', 3, '黄瓜病毒病', 'ພະຍາດໄວຣັສໝາກແຕງ', 'Cucumber Mosaic Virus',
 'Cucumber mosaic virus (CMV)',
 'disease', 'severe',
 '[AI识别] 幼苗期植株矮化、生长迟缓；叶片出现深绿与浅绿相间的花叶症状，叶缘上卷，叶片皱缩变小；部分植株顶部嫩叶明显缩小并丛生，整株表现为严重矮化。由蚜虫和白粉虱传播，苗期感染产量损失可达50-80%。[建议专家审核]',
 '[AI ກວດພົບ] ຕົ້ນກ້າບໍ່ໂຕ, ໃບມີລາຍສີຂຽວເຂັ້ມ-ອ່ອນ, ຂອບໃບ​ດ້ວງ, ໃບນ້ອຍງ. ຕົ້ນກ້າໄດ້ຮັບເຊື້ອສູນເສຍ 50-80%. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '高温干旱年份发病重，蚜虫虫口密度大时传播快。育苗期保护地防虫不严时易感染。',
 'ປີທີ່ຮ້ອນແຫ້ງ, ເພີ້ຍຫຼາຍ, ຂາດການປ້ອງກັນແມງໄມ້.',
 '病毒,花叶,矮化,蚜虫传播,CMV,苗期', 'FIELD_COLLECTION'),

-- 图片: 果类瓜类2.jpg — 穴盘苗煤污病
('vegetable', 3, '黄瓜苗煤污病', 'ພະຍາດດຳ ຕົ້ນກ້າໝາກແຕງ', 'Sooty Mold on Cucumber Seedling',
 'Capnodium spp. / Meliola spp.',
 'disease', 'mild',
 '[AI识别] 穴盘幼苗叶面覆盖黑色烟灰状霉层，影响光合作用；叶片发黄、萎蔫，部分幼苗死亡。煤污病本身为次生病害，由白粉虱/蚜虫分泌的蜜露滋生真菌所致，需同时防治媒介害虫。[建议专家审核]',
 '[AI ກວດພົບ] ໃບຕົ້ນກ້າ (ໃນກ່ອງ) ມີຝຸ່ນດຳ, ຂັດຂວາງການສັງເຄາະ. ໃບເຫຼືອງຫ່ຽວ, ບາງຕົ້ນຕາຍ. ເກີດຈາກ​ ນ້ຳໜຽວ​ ເພີ້ຍ/ຂີ້ຝ້ອຍ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度25-30°C，大棚内通风不良、白粉虱/蚜虫大量发生时继发。高湿环境蔓延快。',
 'ອາກາດຮ້ອນ 25-30°C, ເຮືອນຕາໄຂ່ລົມຂ້າງບໍ່ດີ, ມີໄສ້ເດືອນ/ເພີ້ຍ.',
 '煤污,黑霉,幼苗,次生病害,白粉虱,蚜虫,育苗', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 蔬菜通用白粉虱 (关联白菜 crop_id=4)
-- ─────────────────────────────────────────

-- 图片: 蔬菜4.jpg — 瓜类/蔬菜叶背白粉虱特写
('vegetable', 4, '白粉虱(蔬菜)', 'ແມງໄມ້ຂາວຜີເສື້ອ ຜັກ', 'Whitefly on Vegetables',
 'Bemisia tabaci',
 'pest', 'moderate',
 '[AI识别] 叶片背面密集分布白色小飞虫（烟粉虱，体长约1mm），白色翅膀明显，用手轻触即大量飞起如白色烟雾。虫体及卵集中于新叶背面叶脉两侧。危害多种蔬菜，吸食汁液导致叶片褪绿，并传播多种病毒病。[建议专家审核]',
 '[AI ກວດພົບ] ໃຕ້ໃບ ແມງໄມ້ຂາວ (~1mm) ຫຼາຍ, ປີກຂາວ, ແຕະໃຫ້ບິນຄ້າຍຄວັນ. ໄຂ່ຢູ່ໃຕ້ໃບອ່ອນ. ດູດນ້ຳ, ໃບຈາງ, ແຜ່ໄວຣັສ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '温度25-32°C，大棚内终年可发生，旱季危害最重，是多种病毒病的主要传播媒介。',
 'ອຸນຫະພູມ 25-32°C, ໃນເຮືອນຕາໄຂ່ຕະຫຼອດປີ, ລະດູແລ້ງຮຸນແຮງ.',
 '白粉虱,烟粉虱,叶背,叶褪绿,病毒媒介,大棚,蔬菜通用', 'FIELD_COLLECTION'),

-- ─────────────────────────────────────────
-- 番茄细菌性枯萎病 (crop_id=2)
-- ─────────────────────────────────────────

-- 图片: 果类瓜类4-细菌病.jpg — 番茄茎叶全面枯死腐败
('vegetable', 2, '番茄细菌性茎腐病', 'ພະຍາດເນົ່າລຳຕົ້ນໝາກເລັ່ນ', 'Bacterial Stem Rot of Tomato',
 'Pectobacterium carotovorum / Pseudomonas corrugata',
 'disease', 'severe',
 '[AI识别] 植株茎基部及中部出现水渍状软腐斑，表面有白色絮状菌丝（需进一步确认是否混合真菌侵染）；叶片全部枯萎下垂变褐，整株枯死，绿色小番茄悬挂于枯枝上。病株有腐臭气味，细菌可通过伤口或地面水流传播。[建议专家审核]',
 '[AI ກວດພົບ] ໂຄນ-ກາງລຳຕົ້ນ​ ເນົ່ານ້ຳ, ມີໃຍຂາວ (ອາດຜະສົມເຊື້ອເຫັດ). ໃບຫ່ຽວດຳ, ທັງຕົ້ນຕາຍ. ມີກິ່ນເໝັນ, ແຜ່ທາງນ້ຳ/ບາດແຜ. [ຂໍໃຫ້ຜູ້ຊ່ຽວຊານຢືນຢັນ]',
 '高温高湿（28-35°C），积水或过度灌溉时爆发。机械损伤、虫伤、施肥烧根后易侵入。连作地块严重。',
 'ອາກາດຮ້ອນຊຸ່ມ (28-35°C), ນ້ຳຂັງ. ບາດແຜ/ທຳລາຍ, ປູກຊ້ຳ.',
 '细菌,茎腐,枯死,软腐,积水,连作,土传', 'FIELD_COLLECTION');

-- ==========================================
-- 4. 防控方案 — 针对新增病虫害
-- ==========================================
-- 以下disease_id为预估值（假设新增从ID 29开始）
-- 实际生产环境建议使用子查询: (SELECT id FROM core.disease WHERE name_zh='草莓白粉虱')
-- ==========================================

-- 草莓白粉虱 (预估 disease_id=29)
INSERT INTO core.prevention_plan (disease_id, plan_type, title_zh, title_lo) VALUES
((SELECT id FROM core.disease WHERE name_zh='草莓白粉虱' LIMIT 1), 'chemical',     '化学防治', 'ການປ້ອງກັນທາງເຄມີ'),
((SELECT id FROM core.disease WHERE name_zh='草莓白粉虱' LIMIT 1), 'biological',    '生物防治', 'ການປ້ອງກັນທາງຊີວະພາບ'),
((SELECT id FROM core.disease WHERE name_zh='草莓白粉虱' LIMIT 1), 'cultivation',   '农业防治', 'ການຈັດການການປູກ'),

-- 草莓灰霉病
((SELECT id FROM core.disease WHERE name_zh='草莓灰霉病' LIMIT 1), 'chemical',    '化学防治', 'ການປ້ອງກັນທາງເຄມີ'),
((SELECT id FROM core.disease WHERE name_zh='草莓灰霉病' LIMIT 1), 'cultivation', '农业防治', 'ການຈັດການການປູກ'),

-- 火龙果茎枯病
((SELECT id FROM core.disease WHERE name_zh='火龙果茎枯病' LIMIT 1), 'chemical',    '化学防治', 'ການປ້ອງກັນທາງເຄມີ'),
((SELECT id FROM core.disease WHERE name_zh='火龙果茎枯病' LIMIT 1), 'cultivation', '农业防治', 'ການຈັດການການປູກ'),

-- 草地贪夜蛾
((SELECT id FROM core.disease WHERE name_zh='草地贪夜蛾(甜玉米)' LIMIT 1), 'chemical',    '化学防治', 'ການປ້ອງກັນທາງເຄມີ'),
((SELECT id FROM core.disease WHERE name_zh='草地贪夜蛾(甜玉米)' LIMIT 1), 'biological',  '生物防治', 'ການປ້ອງກັນທາງຊີວະພາບ'),

-- 百香果叶枯病
((SELECT id FROM core.disease WHERE name_zh='百香果叶枯病' LIMIT 1), 'chemical',    '化学防治', 'ການປ້ອງກັນທາງເຄມີ'),

-- 百香果炭疽病
((SELECT id FROM core.disease WHERE name_zh='百香果炭疽病' LIMIT 1), 'chemical',    '化学防治', 'ການປ້ອງກັນທາງເຄມີ');

-- ==========================================
-- 5. 防控措施条目
-- ==========================================
INSERT INTO core.prevention_item (plan_id, name_zh, name_lo, usage_zh, usage_lo) VALUES

-- 草莓白粉虱 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='chemical' LIMIT 1),
 '25%噻虫嗪水分散粒剂2500倍液', 'ຢາ Thiamethoxam 25%',
 '叶面喷雾，重点喷叶背。每7-10天喷1次，连续2次。采收前7天停药。', 'ສີດໃຕ້ໃບ ທຸກ 7-10 ມື້, ສີດ 2 ຄັ້ງ. ຢຸດ 7 ມື້ກ່ອນເກັບ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='chemical' LIMIT 1),
 '10%吡虫啉可湿性粉剂1500倍液', 'ຢາ Imidacloprid 10%',
 '与噻虫嗪交替使用，防止产生抗药性。', 'ສະຫຼັບກັບ Thiamethoxam ເພື່ອຫຼີກລ່ຽງການຕ້ານທານ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='chemical' LIMIT 1),
 '22.4%螺虫乙酯悬浮剂4000倍液', 'ຢາ Spirotetramat 22.4%',
 '对成虫和若虫均有效，持效期长。', 'ໃຊ້ໄດ້ທັງໂຕແກ່ແລະດັກແດ້, ຢູ່ໄດ້ດົນ.'),

-- 草莓白粉虱 生物防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='biological' LIMIT 1),
 '悬挂黄色粘虫板', 'ຕິດຕັ້ງກາວດັກແມງໄມ້ສີເຫຼືອງ',
 '每亩悬挂30-40块（25×30cm），高于植株10-15cm，每月更换。', 'ຕໍ່ 1 ໄຮ ຕິດ 30-40 ແຜ່ນ, ສູງກວ່າຕົ້ນ 10-15cm, ປ່ຽນທຸກເດືອນ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='biological' LIMIT 1),
 '释放丽蚜小蜂', 'ປ່ອຍຜຶ້ງ Encarsia formosa',
 '在白粉虱发生初期释放，每株5-10头，每2周释放1次。', 'ໃນຕອນຕົ້ນ, ປ່ອຍ 5-10 ໂຕ/ຕົ້ນ, ທຸກ 2 ອາທິດ.'),

-- 草莓白粉虱 农业防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='cultivation' LIMIT 1),
 '大棚入口安装防虫网', 'ຕິດຕາຂ່າຍກັນແມງໄມ້ທາງເຂົ້າ',
 '40-60目防虫网，阻止成虫飞入大棚。', '40-60 ຕາ, ກັນໂຕແກ່ບິນເຂົ້າ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓白粉虱' AND pp.plan_type='cultivation' LIMIT 1),
 '清除大棚内外杂草', 'ກວາດຫຍ້າໃນ-ນອກເຮືອນ',
 '减少白粉虱寄主，定期清洁大棚四周。', 'ຫຼຸດຕົ້ນໄມ້ຢາຂອງແມງໄມ້, ທຳຄວາມສະອາດ.'),

-- 草莓灰霉病 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓灰霉病' AND pp.plan_type='chemical' LIMIT 1),
 '50%腐霉利可湿性粉剂1000倍液', 'ຢາ Procymidone 50%',
 '花期开始预防，每7天喷1次，采收前14天停药。', 'ເລີ່ມສີດຊ່ວງດອກ, ທຸກ 7 ມື້, ຢຸດ 14 ມື້ກ່ອນເກັບ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓灰霉病' AND pp.plan_type='chemical' LIMIT 1),
 '40%嘧霉胺悬浮剂1000倍液', 'ຢາ Pyrimethanil 40%',
 '与腐霉利交替使用，减少抗药性。', 'ສະຫຼັບກັນ, ຫຼຸດການຕ້ານທານ.'),

-- 草莓灰霉病 农业防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓灰霉病' AND pp.plan_type='cultivation' LIMIT 1),
 '控制大棚湿度<80%', 'ຄວບຄຸມຄວາມຊຸ່ມ <80%',
 '早晨通风排湿，避免傍晚浇水，采用滴灌方式。', 'ເຊົ້າລະບາຍຄວາມຊຸ່ມ, ຫຼີກລ່ຽງຮົດນ້ຳຕອນແລງ, ໃຊ້ລະບົບດຸ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草莓灰霉病' AND pp.plan_type='cultivation' LIMIT 1),
 '及时摘除病果病花', 'ເກັບໝາກ/ດອກທີ່ເປັນພະຍາດ',
 '发现病果立即摘除装袋带出，减少侵染源。', 'ທີ່ເຫັນໃຫ້ເກັບທັນທີ, ໃສ່ຖົງນຳອອກ.'),

-- 火龙果茎枯病 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='火龙果茎枯病' AND pp.plan_type='chemical' LIMIT 1),
 '25%咪鲜胺乳油1000倍液', 'ຢາ Prochloraz 25%',
 '发病初期喷雾或涂抹病斑，每10天处理1次，连续3次。', 'ຕອນຕົ້ນ, ສີດຫຼືທາ, ທຸກ 10 ມື້, 3 ຄັ້ງ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='火龙果茎枯病' AND pp.plan_type='chemical' LIMIT 1),
 '70%甲基硫菌灵可湿性粉剂800倍液', 'ຢາ Thiophanate-methyl 70%',
 '发病初期喷雾防治，雨前预防效果最佳。', 'ສີດກ່ອນຝົນຈະໄດ້ຜົນດີ.'),

-- 火龙果茎枯病 农业防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='火龙果茎枯病' AND pp.plan_type='cultivation' LIMIT 1),
 '修剪病茎及时清除', 'ຕັດລຳຕົ້ນທີ່ເປັນພະຍາດ',
 '将病茎剪除至健康组织以下2-3cm，刀具消毒，切口涂抹波尔多液。', 'ຕັດ 2-3cm ຕ່ຳກວ່າຈຸດເປັນພະຍາດ, ຂ້າເຊື້ອເຄື່ອງ, ທາໂບໂດ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='火龙果茎枯病' AND pp.plan_type='cultivation' LIMIT 1),
 '雨季提前排水', 'ລະດູຝົນລ່ວງໜ້າລະບາຍນ້ຳ',
 '疏通排水沟，避免积水，适当修剪密枝改善通风。', 'ຊ່ອງທາງລະບາຍ, ຫຼີກລ່ຽງນ້ຳຂັງ, ຕັດງ່າແໜ້ນ.'),

-- 草地贪夜蛾 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草地贪夜蛾(甜玉米)' AND pp.plan_type='chemical' LIMIT 1),
 '5%甲氨基阿维菌素苯甲酸盐2000倍液', 'ຢາ Emamectin benzoate 5%',
 '在3龄前幼虫期施药，直接喷入心叶效果最佳，每5-7天喷1次。', 'ສີດຕອນໜອນ 3 ໄວ, ສີດເຂົ້າໃຈ, ທຸກ 5-7 ມື້.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草地贪夜蛾(甜玉米)' AND pp.plan_type='chemical' LIMIT 1),
 '10%四氯虫酰胺悬浮剂1000倍液', 'ຢາ Tetrachlorantraniliprole 10%',
 '选择在清晨或傍晚用药，利用幼虫活动高峰期。', 'ສີດຕອນເຊົ້າຫຼືຕອນແລງ, ຕອນທີ່ໜອນເຄື່ອນໄຫວ.'),

-- 草地贪夜蛾 生物防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草地贪夜蛾(甜玉米)' AND pp.plan_type='biological' LIMIT 1),
 '苏云金芽孢杆菌(Bt)制剂', 'ຢາ Bacillus thuringiensis (Bt)',
 '在初孵幼虫至2龄期施用，每亩用Bt 100-200g，加水喷雾。', 'ໃຊ້ຕອນໜອນ 1-2 ໄວ, 100-200g/ໄຮ ສີດ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='草地贪夜蛾(甜玉米)' AND pp.plan_type='biological' LIMIT 1),
 '悬挂性信息素诱捕器', 'ຕິດຕັ້ງດັກ Pheromone',
 '每亩设1-2个性诱捕器，每月更换诱芯，监测虫口密度。', 'ຕໍ່ 1 ໄຮ ຕິດ 1-2 ດັກ, ປ່ຽນ Pheromone ທຸກເດືອນ.'),

-- 百香果叶枯病 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='百香果叶枯病' AND pp.plan_type='chemical' LIMIT 1),
 '80%代森锰锌可湿性粉剂600倍液', 'ຢາ Mancozeb 80%',
 '雨季前开始预防，每10-14天喷1次，连续3次。', 'ກ່ອນລະດູຝົນ, ທຸກ 10-14 ມື້, 3 ຄັ້ງ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='百香果叶枯病' AND pp.plan_type='chemical' LIMIT 1),
 '40%苯醚甲环唑悬浮剂6000倍液', 'ຢາ Difenoconazole 40%',
 '发病后治疗性喷药，与代森锰锌交替使用。', 'ຫຼັງເກີດພະຍາດ, ສະຫຼັບ Mancozeb.'),

-- 百香果炭疽病 化学防治
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='百香果炭疽病' AND pp.plan_type='chemical' LIMIT 1),
 '25%咪鲜胺乳油1000倍液', 'ຢາ Prochloraz 25%',
 '发病初期开始喷药，每7-10天1次，花期和幼果期重点防治。', 'ຕອນຕົ້ນ, ທຸກ 7-10 ມື້, ດອກ-ໝາກອ່ອນ ສຳຄັນ.'),
((SELECT pp.id FROM core.prevention_plan pp JOIN core.disease d ON pp.disease_id=d.id WHERE d.name_zh='百香果炭疽病' AND pp.plan_type='chemical' LIMIT 1),
 '70%甲基硫菌灵可湿性粉剂1000倍液', 'ຢາ Thiophanate-methyl 70%',
 '与咪鲜胺交替使用。采收前14天停药。', 'ສະຫຼັບ Prochloraz. ຢຸດ 14 ມື້ກ່ອນເກັບ.');

-- ==========================================
-- 验证查询
-- ==========================================
-- SELECT c.name_zh AS 作物, d.name_zh AS 病虫害, d.type, d.severity_level, d.source_type
-- FROM core.crop c JOIN core.disease d ON c.id = d.crop_id
-- WHERE d.source_type = 'FIELD_COLLECTION'
-- ORDER BY c.version, c.id, d.id;
