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
package org.apache.fineract.customproducts.groupsavings.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * Wrapper around the core GSIM (Group Savings Individual Monitoring) lifecycle. Apply business rules specific to the
 * bundled "Group Savings with Interest" customer offering here, then delegate to the existing core GSIM write platform
 * service.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class CustomProductsGroupSavingsWriteService {

    public Long openGroupSavingsAccount(String customProductCode, Long groupId) {
        log.info("CustomProducts.groupsavings open requested code={} groupId={}", customProductCode, groupId);
        return null;
    }
}
