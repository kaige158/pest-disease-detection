package com.laos.agri.entity;

/**
 * 数据来源类型 — 所有农业数据必须标注来源
 */
public enum SourceType {
    TEACHER_DATA,       // 老师提供的语料
    USER_UPLOAD,        // 用户拍照上传
    FIELD_COLLECTION,   // 技术员田野采集
    AI_GENERATED        // AI生成经人工确认
}
