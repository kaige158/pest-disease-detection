package com.laos.agri.repository;

import com.laos.agri.entity.TrainingDataset;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface TrainingDatasetRepository extends JpaRepository<TrainingDataset, Long> {

    Optional<TrainingDataset> findByAssetId(String assetId);

    Optional<TrainingDataset> findByDiagnosisId(Long diagnosisId);

    // 训练就绪数据
    @Query("SELECT t FROM TrainingDataset t WHERE t.trainingReady = true AND t.isActive = true")
    Page<TrainingDataset> findTrainingReady(Pageable pageable);

    @Query("SELECT COUNT(t) FROM TrainingDataset t WHERE t.trainingReady = true AND t.isActive = true")
    long countTrainingReady();

    // 按作物统计
    @Query("SELECT t.cropZh, COUNT(t), " +
           "SUM(CASE WHEN t.trainingReady = true THEN 1 ELSE 0 END) " +
           "FROM TrainingDataset t WHERE t.isActive = true " +
           "GROUP BY t.cropZh ORDER BY COUNT(t) DESC")
    List<Object[]> countByCrop();

    // 按病害统计
    @Query("SELECT t.diseaseZh, COUNT(t), " +
           "SUM(CASE WHEN t.trainingReady = true THEN 1 ELSE 0 END) " +
           "FROM TrainingDataset t WHERE t.isActive = true " +
           "GROUP BY t.diseaseZh ORDER BY COUNT(t) DESC")
    List<Object[]> countByDisease();

    // 按AI模型统计
    @Query("SELECT t.aiModel, COUNT(t), " +
           "SUM(CASE WHEN t.trainingReady = true THEN 1 ELSE 0 END), " +
           "AVG(t.aiConfidence) " +
           "FROM TrainingDataset t WHERE t.isActive = true AND t.aiModel IS NOT NULL " +
           "GROUP BY t.aiModel ORDER BY COUNT(t) DESC")
    List<Object[]> countByAiModel();

    // 导出就绪数据
    @Query("SELECT t FROM TrainingDataset t WHERE t.trainingReady = true " +
           "AND t.isActive = true AND t.exportBatch IS NULL " +
           "ORDER BY t.cropZh, t.diseaseZh")
    List<TrainingDataset> findUnexportedTrainingReady();

    // 按批次查询
    List<TrainingDataset> findByExportBatch(String exportBatch);
}
