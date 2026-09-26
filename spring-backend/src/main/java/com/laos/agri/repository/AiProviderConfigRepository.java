package com.laos.agri.repository;

import com.laos.agri.entity.AiProviderConfig;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface AiProviderConfigRepository extends JpaRepository<AiProviderConfig, Long> {

    /** 当前生效的 AI 通道（业务上最多一行） */
    Optional<AiProviderConfig> findFirstByIsActiveTrue();

    List<AiProviderConfig> findAllByOrderByIdAsc();

    Optional<AiProviderConfig> findByProvider(String provider);

    boolean existsByProvider(String provider);
}
