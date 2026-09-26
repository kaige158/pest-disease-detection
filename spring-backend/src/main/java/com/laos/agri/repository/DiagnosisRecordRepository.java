package com.laos.agri.repository;

import com.laos.agri.entity.DiagnosisRecord;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface DiagnosisRecordRepository extends JpaRepository<DiagnosisRecord, Long> {
    Optional<DiagnosisRecord> findByTaskId(String taskId);
    Page<DiagnosisRecord> findByUserIdOrderByCreatedAtDesc(Long userId, Pageable pageable);

    // 待审核列表 (专家未审核 + 已完成状态)
    @Query("SELECT d FROM DiagnosisRecord d WHERE d.expertReviewed = false " +
           "AND d.status IN ('completed', 'reviewed') ORDER BY d.createdAt DESC")
    Page<DiagnosisRecord> findPendingReview(Pageable pageable);

    // 按版本和状态统计
    @Query("SELECT d.version, COUNT(d) FROM DiagnosisRecord d GROUP BY d.version")
    List<Object[]> countByVersion();

    // ===== 删除用户时需要连带清理的数据 =====

    /** 某用户的全部识别记录（删除前要先取出 image_url，磁盘文件也要一起删） */
    List<DiagnosisRecord> findByUserId(Long userId);

    long countByUserId(Long userId);
}
