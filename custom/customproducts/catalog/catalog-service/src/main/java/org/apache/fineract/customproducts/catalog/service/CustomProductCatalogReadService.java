/**
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements. See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership. The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
package org.apache.fineract.customproducts.catalog.service;

import java.util.List;
import lombok.RequiredArgsConstructor;
import org.apache.fineract.customproducts.catalog.data.CustomProductCatalogData;
import org.apache.fineract.customproducts.catalog.domain.CustomProductCatalog;
import org.apache.fineract.customproducts.catalog.domain.CustomProductCatalogRepository;
import org.apache.fineract.customproducts.catalog.domain.CustomProductFamily;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class CustomProductCatalogReadService {

    private final CustomProductCatalogRepository repository;

    @Transactional(readOnly = true)
    public List<CustomProductCatalogData> findAll() {
        return repository.findAll().stream().map(CustomProductCatalogReadService::toData).toList();
    }

    @Transactional(readOnly = true)
    public List<CustomProductCatalogData> findEnabledByFamily(CustomProductFamily family) {
        return repository.findByFamilyAndEnabledTrue(family).stream().map(CustomProductCatalogReadService::toData).toList();
    }

    @Transactional(readOnly = true)
    public CustomProductCatalogData findByCode(String code) {
        return repository.findByCode(code).map(CustomProductCatalogReadService::toData).orElse(null);
    }

    private static CustomProductCatalogData toData(CustomProductCatalog entity) {
        return CustomProductCatalogData.builder().id(entity.getId()).code(entity.getCode()).displayName(entity.getDisplayName())
                .family(entity.getFamily()).coreSavingsProductId(entity.getCoreSavingsProductId())
                .marketingTagline(entity.getMarketingTagline()).iconUrl(entity.getIconUrl()).enabled(entity.isEnabled()).build();
    }
}
