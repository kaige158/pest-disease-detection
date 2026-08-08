package com.laos.agri.entity;

/**
 * 数据质量等级 — S/A/B/C/D 五级
 */
public enum DataGrade {
    S,      // 黄金: 专家标注 + 图片清晰 + 元数据完整
    A,      // 银: AI高置信度 + 用户确认
    B,      // 铜: AI中置信度 + 专家审核
    C,      // 参考: 低置信度 + 专家修正(困难样本)
    D       // 废弃: 图片模糊/无法判断
}
