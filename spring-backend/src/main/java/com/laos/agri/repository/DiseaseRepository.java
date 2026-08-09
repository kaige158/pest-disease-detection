package com.laos.agri.repository;

import com.laos.agri.entity.Disease;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface DiseaseRepository extends JpaRepository<Disease, Integer> {
    List<Disease> findByVersionAndIsActiveTrue(String version);
    List<Disease> findByCropIdAndIsActiveTrue(Integer cropId);
    List<Disease> findByTypeAndVersionAndIsActiveTrue(String type, String version);
    List<Disease> findByNameZhContaining(String nameZh);

    @Query(value = "SELECT * FROM disease WHERE version = :version AND is_active = true " +
           "AND to_tsvector('simple', COALESCE(name_zh,'') || ' ' || COALESCE(name_lo,'') || ' ' || " +
           "COALESCE(symptoms_zh,'') || ' ' || COALESCE(tags,'')) @@ plainto_tsquery('simple', :query)",
           nativeQuery = true)
    List<Disease> search(@Param("version") String version, @Param("query") String query);
}
