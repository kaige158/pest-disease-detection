package com.laos.agri.repository;

import com.laos.agri.entity.KnowledgeArticle;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface KnowledgeArticleRepository extends JpaRepository<KnowledgeArticle, Integer> {
    Page<KnowledgeArticle> findByVersionAndIsPublishedTrue(String version, Pageable pageable);
    List<KnowledgeArticle> findByCropIdAndIsPublishedTrue(Integer cropId);
    List<KnowledgeArticle> findByDiseaseIdAndIsPublishedTrue(Integer diseaseId);

    @Query(value = "SELECT * FROM knowledge_article WHERE version = :version AND is_published = true " +
           "AND to_tsvector('simple', COALESCE(title_zh,'') || ' ' || COALESCE(title_lo,'') || ' ' || " +
           "COALESCE(content_zh,'') || ' ' || COALESCE(tags,'')) @@ plainto_tsquery('simple', :query)",
           nativeQuery = true)
    Page<KnowledgeArticle> search(@Param("version") String version, @Param("query") String query, Pageable pageable);
}
