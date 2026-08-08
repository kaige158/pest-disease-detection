/// 离线知识库 — 内置病虫害基础数据，无网络也能查询
///
/// 设计策略:
/// - 不依赖sqflite原生插件(避免复杂的原生依赖)
/// - 直接用Dart代码内置JSON数据
/// - 数据随APP打包，首次启动加载到内存
/// - 联网时通过API增量更新

class OfflineKnowledge {
  static final OfflineKnowledge _instance = OfflineKnowledge._();
  factory OfflineKnowledge() => _instance;
  OfflineKnowledge._();

  final List<Map<String, dynamic>> _diseases = [];
  final Map<String, List<Map<String, dynamic>>> _diseasesByCrop = {};
  bool _loaded = false;

  /// 加载内置数据
  void loadBuiltinData() {
    if (_loaded) return;
    _loadVegetableData();
    _loadFruitData();
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  /// 搜索病虫害 (离线)
  List<Map<String, dynamic>> search(String query, {String version = 'vegetable'}) {
    final q = query.toLowerCase();
    return _diseases.where((d) {
      if (d['version'] != version) return false;
      final name = (d['name_zh'] ?? '').toLowerCase();
      final nameLo = (d['name_lo'] ?? '').toLowerCase();
      final symptoms = (d['symptoms_zh'] ?? '').toLowerCase();
      final tags = (d['tags'] ?? '').toLowerCase();
      return name.contains(q) || nameLo.contains(q) || symptoms.contains(q) || tags.contains(q);
    }).toList();
  }

  /// 按作物获取病虫害列表
  List<Map<String, dynamic>> getByCrop(String cropName) {
    return _diseasesByCrop[cropName] ?? [];
  }

  /// 获取所有病虫害
  List<Map<String, dynamic>> getAll() => List.unmodifiable(_diseases);

  /// 获取所有作物名
  List<String> getCropNames(String version) {
    return _diseasesByCrop.keys.where((k) {
      final diseases = _diseasesByCrop[k]!;
      return diseases.any((d) => d['version'] == version);
    }).toList();
  }

  // ===== 内置数据 =====

  void _loadVegetableData() {
    final diseases = [
      {
        'id': 1, 'version': 'vegetable', 'crop_name_zh': '番茄', 'crop_name_lo': 'ໝາກເລັ່ນ',
        'name_zh': '番茄晚疫病', 'name_lo': 'ພະຍາດໃບໄໝ້ໝາກເລັ່ນ',
        'type': 'disease', 'severity': 'severe', 'tags': '晚疫,疫病,叶斑',
        'symptoms_zh': '叶片出现水渍状暗绿色斑点，湿度大时叶背有白色霉层，严重时全株枯死。',
        'symptoms_lo': 'ໃບມີຈຸດສີຂຽວເຂັ້ມ, ເມື່ອມີຄວາມຊຸ່ມສູງຈະມີເຊື້ອສີຂາວຢູ່ໃຕ້ໃບ.',
        'conditions_zh': '温度18-22°C，相对湿度>95%时易发病。',
        'prevention_zh': '1. 58%甲霜灵锰锌500倍液，每7天喷1次\n2. 选用抗病品种\n3. 合理密植，加强通风',
        'prevention_lo': '1. ຢາ Metalaxyl 58%, ສີດທຸກໆ 7 ມື້\n2. ເລືອກແນວພັນທີ່ຕ້ານທານ',
      },
      {
        'id': 2, 'version': 'vegetable', 'crop_name_zh': '番茄', 'crop_name_lo': 'ໝາກເລັ່ນ',
        'name_zh': '番茄早疫病', 'name_lo': 'ພະຍາດໃບຈຸດໝາກເລັ່ນ',
        'type': 'disease', 'severity': 'moderate', 'tags': '早疫,轮纹,叶斑',
        'symptoms_zh': '叶片出现圆形褐色斑点，有明显同心轮纹，严重时叶片干枯脱落。',
        'symptoms_lo': 'ໃບມີຈຸດສີນ້ຳຕານເປັນວົງ, ເມື່ອເປັນຫຼາຍໃບຈະຫ່ຽວແຫ້ງ.',
        'conditions_zh': '温度26-28°C，多雨时易发病。',
        'prevention_zh': '1. 70%代森锰锌500倍液\n2. 轮作倒茬\n3. 清除病残体',
        'prevention_lo': '1. ຢາ Mancozeb 70%\n2. ປູກພືດໝູນວຽນ',
      },
      {
        'id': 3, 'version': 'vegetable', 'crop_name_zh': '白菜', 'crop_name_lo': 'ຜັກກາດຂາວ',
        'name_zh': '白菜黑斑病', 'name_lo': 'ພະຍາດຈຸດດຳຜັກກາດ',
        'type': 'disease', 'severity': 'moderate', 'tags': '黑斑,斑点,叶斑',
        'symptoms_zh': '叶片出现圆形黑褐色斑点，严重时连片枯死。',
        'symptoms_lo': 'ໃບມີຈຸດສີນ້ຳຕານດຳ, ເມື່ອເປັນຫຼາຍໃບຈະຕາຍ.',
        'conditions_zh': '温度25-30°C，多雨潮湿时发病重。',
        'prevention_zh': '1. 50%多菌灵500倍液，每7-10天1次\n2. 轮作倒茬\n3. 清除病残体',
        'prevention_lo': '1. ຢາ Carbendazim 50%\n2. ປູກພືດໝູນວຽນ',
      },
      {
        'id': 4, 'version': 'vegetable', 'crop_name_zh': '白菜', 'crop_name_lo': 'ຜັກກາດຂາວ',
        'name_zh': '白菜软腐病', 'name_lo': 'ພະຍາດເນົ່າຜັກກາດ',
        'type': 'disease', 'severity': 'severe', 'tags': '软腐,腐烂,细菌',
        'symptoms_zh': '茎基部或叶柄出现水渍状软腐，有恶臭味，严重时整株腐烂。',
        'symptoms_lo': 'ລຳຕົ້ນເນົ່າ, ມີກິ່ນເໝັນ, ຮຸນແຮງທັງຕົ້ນ.',
        'conditions_zh': '高温高湿，28-35°C时易发病，雨后积水加重。',
        'prevention_zh': '1. 72%农用链霉素3000倍液\n2. 高畦栽培，避免积水\n3. 及时拔除病株',
        'prevention_lo': '1. ຢາ Streptomycin 72%\n2. ຫຼີກລ່ຽງນ້ຳຂັງ',
      },
      {
        'id': 5, 'version': 'vegetable', 'crop_name_zh': '辣椒', 'crop_name_lo': 'ໝາກເຜັດ',
        'name_zh': '辣椒炭疽病', 'name_lo': 'ພະຍາດແອນແທຣກໂນສໝາກເຜັດ',
        'type': 'disease', 'severity': 'moderate', 'tags': '炭疽,果实,斑点',
        'symptoms_zh': '果实出现圆形凹陷病斑，边缘褐色，中央灰白色，有黑色小点。',
        'symptoms_lo': 'ໝາກມີຈຸດວົງ, ຂອບສີນ້ຳຕານ, ກາງສີຂາວ.',
        'conditions_zh': '温度25-28°C，湿度>90%时易发病。',
        'prevention_zh': '1. 70%甲基托布津800倍液\n2. 及时摘除病果\n3. 合理施肥，增施磷钾肥',
        'prevention_lo': '1. ຢາ Thiophanate-methyl 70%\n2. ເກັບໝາກທີ່ເປັນພະຍາດອອກ',
      },
      {
        'id': 6, 'version': 'vegetable', 'crop_name_zh': '黄瓜', 'crop_name_lo': 'ໝາກແຕງ',
        'name_zh': '黄瓜霜霉病', 'name_lo': 'ພະຍາດຂີ້ຝຸ່ນໝາກແຕງ',
        'type': 'disease', 'severity': 'moderate', 'tags': '霜霉,叶斑,黄斑',
        'symptoms_zh': '叶片出现多角形黄色斑点，叶背有紫灰色霉层，严重时叶片枯焦。',
        'symptoms_lo': 'ໃບມີຈຸດສີເຫຼືອງ, ໃຕ້ໃບມີເຊື້ອສີມ່ວງ, ເມື່ອເປັນຫຼາຍໃບຈະແຫ້ງ.',
        'conditions_zh': '16-22°C，湿度>90%时严重。',
        'prevention_zh': '1. 72%霜脲·锰锌600倍液\n2. 加强通风降湿\n3. 合理浇水，避免叶面长时间潮湿',
        'prevention_lo': '1. ຢາ Cymoxanil 72%\n2. ຫຼຸດຄວາມຊຸ່ມ',
      },
      {
        'id': 7, 'version': 'vegetable', 'crop_name_zh': '辣椒', 'crop_name_lo': 'ໝາກເຜັດ',
        'name_zh': '辣椒疫病', 'name_lo': 'ພະຍາດລຳຕົ້ນເນົ່າໝາກເຜັດ',
        'type': 'disease', 'severity': 'severe', 'tags': '疫病,根腐,萎蔫',
        'symptoms_zh': '茎基部出现水渍状褐色病斑，植株迅速萎蔫死亡，维管束不变色。',
        'symptoms_lo': 'ລຳຕົ້ນມີຈຸດສີນ້ຳຕານ, ຕົ້ນຫ່ຽວຕາຍຢ່າງວ່ອງໄວ.',
        'conditions_zh': '高温多雨，28-32°C时最易发病。',
        'prevention_zh': '1. 25%甲霜灵可湿性粉剂800倍液\n2. 高畦栽培\n3. 避免连作',
        'prevention_lo': '1. ຢາ Metalaxyl 25%\n2. ປູກແບບຍົກຮ່ອງ',
      },
      {
        'id': 8, 'version': 'vegetable', 'crop_name_zh': '茄子', 'crop_name_lo': 'ໝາກເຂືອ',
        'name_zh': '茄子褐纹病', 'name_lo': 'ພະຍາດຈຸດສີນ້ຳຕານໝາກເຂືອ',
        'type': 'disease', 'severity': 'moderate', 'tags': '褐纹,叶斑,果实',
        'symptoms_zh': '叶片出现褐色近圆形斑点，果实出现凹陷褐色病斑，后期干腐。',
        'symptoms_lo': 'ໃບມີຈຸດສີນ້ຳຕານ, ໝາກມີຈຸດບຸ້ມ.',
        'conditions_zh': '28-30°C，多雨高湿时发病重。',
        'prevention_zh': '1. 75%百菌清600倍液\n2. 种子消毒\n3. 合理轮作',
        'prevention_lo': '1. ຢາ Chlorothalonil 75%\n2. ອະນາໄມແກ່ນ',
      },
      {
        'id': 9, 'version': 'vegetable', 'crop_name_zh': '白菜', 'crop_name_lo': 'ຜັກກາດ',
        'name_zh': '蚜虫', 'name_lo': 'ເພີ້ຍ',
        'type': 'pest', 'severity': 'moderate', 'tags': '蚜虫,吸汁,虫害',
        'symptoms_zh': '叶片卷曲变形，有粘稠蜜露，蚂蚁活动增多，传播病毒病。',
        'symptoms_lo': 'ໃບຫງິກງໍ, ມີນ້ຳຫວານໜຽວ, ມົດຫຼາຍ.',
        'conditions_zh': '干旱季节发生严重，15-25°C繁殖最快。',
        'prevention_zh': '1. 10%吡虫啉可湿性粉剂2000倍液\n2. 黄板诱杀\n3. 保护瓢虫等天敌',
        'prevention_lo': '1. ຢາ Imidacloprid 10%\n2. ໃຊ້ກັບດັກສີເຫຼືອງ',
      },
      {
        'id': 10, 'version': 'vegetable', 'crop_name_zh': '番茄', 'crop_name_lo': 'ໝາກເລັ່ນ',
        'name_zh': '白粉虱', 'name_lo': 'ແມງຫວີ່ຂາວ',
        'type': 'pest', 'severity': 'moderate', 'tags': '白粉虱,吸汁,烟霉',
        'symptoms_zh': '叶片发黄，叶背密布白色小虫，分泌蜜露导致烟霉病。',
        'symptoms_lo': 'ໃບສີເຫຼືອງ, ໃຕ້ໃບມີແມງສີຂາວນ້ອຍໆ.',
        'conditions_zh': '温暖干燥时发生重，20-30°C。',
        'prevention_zh': '1. 25%噻虫嗪水分散粒剂3000倍液\n2. 黄板诱杀\n3. 清除杂草',
        'prevention_lo': '1. ຢາ Thiamethoxam 25%\n2. ໃຊ້ກັບດັກສີເຫຼືອງ',
      },
    ];

    _diseases.addAll(diseases);
    for (final d in diseases) {
      final crop = d['crop_name_zh'] as String;
      _diseasesByCrop.putIfAbsent(crop, () => []).add(d);
    }
  }

  void _loadFruitData() {
    final diseases = [
      {
        'id': 101, 'version': 'fruit', 'crop_name_zh': '芒果', 'crop_name_lo': 'ໝາກມ່ວງ',
        'name_zh': '芒果炭疽病', 'name_lo': 'ພະຍາດແອນແທຣກໂນສໝາກມ່ວງ',
        'type': 'disease', 'severity': 'severe', 'tags': '炭疽,果腐,叶斑',
        'symptoms_zh': '叶片出现不规则褐色斑点，果实出现黑色凹陷病斑，严重时果实腐烂。',
        'symptoms_lo': 'ໃບມີຈຸດສີນ້ຳຕານ, ໝາກມີຈຸດດຳ, ເມື່ອເປັນຫຼາຍໝາກເນົ່າ.',
        'conditions_zh': '温度25-30°C，多雨高湿时严重。',
        'prevention_zh': '1. 25%咪鲜胺1000倍液\n2. 冬季清园修剪病枝\n3. 套袋保护果实',
        'prevention_lo': '1. ຢາ Prochloraz 25%\n2. ຕັດກິ່ງທີ່ເປັນພະຍາດ',
      },
      {
        'id': 102, 'version': 'fruit', 'crop_name_zh': '香蕉', 'crop_name_lo': 'ກ້ວຍ',
        'name_zh': '香蕉叶斑病', 'name_lo': 'ພະຍາດຈຸດໃບກ້ວຍ',
        'type': 'disease', 'severity': 'severe', 'tags': '叶斑,枯叶,真菌',
        'symptoms_zh': '叶片出现褐色条斑，逐渐扩展融合，严重时叶片大面积枯死，影响产量。',
        'symptoms_lo': 'ໃບມີຈຸດສີນ້ຳຕານ, ຂະຫຍາຍໄປເລື້ອຍໆ, ເມື່ອເປັນຫຼາຍໃບຕາຍ.',
        'conditions_zh': '25-32°C，雨季高发。',
        'prevention_zh': '1. 25%丙环唑1500倍液，每10-14天1次\n2. 及时摘除病叶\n3. 合理施肥增强树势',
        'prevention_lo': '1. ຢາ Propiconazole 25%\n2. ເກັບໃບທີ່ເປັນພະຍາດອອກ',
      },
      {
        'id': 103, 'version': 'fruit', 'crop_name_zh': '荔枝', 'crop_name_lo': 'ໝາກລິ້ນຈີ່',
        'name_zh': '荔枝霜疫霉病', 'name_lo': 'ພະຍາດຂີ້ຝຸ່ນໝາກລິ້ນຈີ່',
        'type': 'disease', 'severity': 'severe', 'tags': '霜疫,果腐,落果',
        'symptoms_zh': '果实表面出现白色霉层，果肉变褐腐烂，大量落果。',
        'symptoms_lo': 'ໝາກມີເຊື້ອສີຂາວ, ເນື້ອໝາກເນົ່າສີນ້ຳຕານ, ໝາກຫຼົ່ນຫຼາຍ.',
        'conditions_zh': '高湿多雨，20-25°C时最易发病。',
        'prevention_zh': '1. 58%甲霜灵锰锌500倍液\n2. 果实套袋\n3. 雨季前喷药预防',
        'prevention_lo': '1. ຢາ Metalaxyl 58%\n2. ຫໍ່ໝາກ',
      },
      {
        'id': 104, 'version': 'fruit', 'crop_name_zh': '柑橘', 'crop_name_lo': 'ໝາກກ້ຽງ',
        'name_zh': '柑橘黄龙病', 'name_lo': 'ພະຍາດໃບເຫຼືອງໝາກກ້ຽງ',
        'type': 'disease', 'severity': 'severe', 'tags': '黄龙,黄化,系统性',
        'symptoms_zh': '叶片斑驳黄化，果实变小畸形，味酸，是柑橘毁灭性病害。',
        'symptoms_lo': 'ໃບມີຈຸດສີເຫຼືອງ, ໝາກນ້ອຍຜິດຮູບ, ລົດຊາດສົ້ມ.',
        'conditions_zh': '由木虱传播，全年均可发生。',
        'prevention_zh': '1. 防治木虱（传播媒介）\n2. 及时挖除病树\n3. 使用无病苗木',
        'prevention_lo': '1. ກຳຈັດແມງໄມ້ພາຫະ\n2. ຂຸດຕົ້ນທີ່ເປັນພະຍາດອອກ',
      },
      {
        'id': 105, 'version': 'fruit', 'crop_name_zh': '芒果', 'crop_name_lo': 'ໝາກມ່ວງ',
        'name_zh': '芒果白粉病', 'name_lo': 'ພະຍາດຂີ້ຝຸ່ນຂາວໝາກມ່ວງ',
        'type': 'disease', 'severity': 'moderate', 'tags': '白粉,花穗,嫩叶',
        'symptoms_zh': '花穗和嫩叶覆盖白色粉状物，影响授粉和坐果。',
        'symptoms_lo': 'ດອກແລະໃບອ່ອນມີຝຸ່ນສີຂາວປົກຄຸມ.',
        'conditions_zh': '干燥温暖季节，20-28°C。',
        'prevention_zh': '1. 硫磺粉喷粉\n2. 25%三唑酮可湿性粉剂1500倍液\n3. 花前预防喷药',
        'prevention_lo': '1. ຜົງກຳມະຖັນ\n2. ຢາ Triadimefon 25%',
      },
      {
        'id': 106, 'version': 'fruit', 'crop_name_zh': '香蕉', 'crop_name_lo': 'ກ້ວຍ',
        'name_zh': '香蕉枯萎病', 'name_lo': 'ພະຍາດຫ່ຽວກ້ວຍ',
        'type': 'disease', 'severity': 'severe', 'tags': '枯萎,维管束,土传',
        'symptoms_zh': '下部叶片先黄化，从叶缘向中脉扩展，假茎维管束变褐，整株枯死。',
        'symptoms_lo': 'ໃບລຸ່ມສີເຫຼືອງກ່ອນ, ລຳຕົ້ນປ່ຽນສີນ້ຳຕານ, ຕົ້ນຕາຍ.',
        'conditions_zh': '土传病害，酸性土壤发病重，28-32°C。',
        'prevention_zh': '1. 选用抗病品种\n2. 土壤改良（施石灰）\n3. 避免病区扩散',
        'prevention_lo': '1. ເລືອກແນວພັນຕ້ານທານ\n2. ປັບປຸງດິນ',
      },
    ];

    _diseases.addAll(diseases);
    for (final d in diseases) {
      final crop = d['crop_name_zh'] as String;
      _diseasesByCrop.putIfAbsent(crop, () => []).add(d);
    }
  }
}
