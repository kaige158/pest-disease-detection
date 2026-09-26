package com.laos.agri.repository;

import com.laos.agri.entity.DiseaseImage;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface DiseaseImageRepository extends JpaRepository<DiseaseImage, Long> {
    Optional<DiseaseImage> findByImageHash(String imageHash);
    List<DiseaseImage> findByDiseaseIdAndIsUsableTrue(Integer diseaseId);

    @Query("SELECT di FROM DiseaseImage di WHERE di.isUsable = true AND di.dataGrade IN ('S','A')")
    List<DiseaseImage> findTrainingQualityImages();

    /**
     * 可用图片数量（按版本）
     *
     * <p>原生 SQL 里**必须写全 core.disease_image**：不带 schema 时由数据库连接的
     * 默认 schema 解析，而业务表都在 core 下 —— 不写全会在"数据统计"接口上报
     * Table "DISEASE_IMAGE" not found（H2 与 PostgreSQL 都一样）。
     */
    @Query(value = "SELECT COUNT(*) FROM core.disease_image WHERE version = :version AND is_usable = true",
           nativeQuery = true)
    long countUsableByVersion(@Param("version") String version);

    /** 挂在某条识别记录下的图片 —— 随识别记录一起删，否则会留下孤儿图片 */
    List<DiseaseImage> findByDiagnosisIdIn(java.util.Collection<Long> diagnosisIds);
}
