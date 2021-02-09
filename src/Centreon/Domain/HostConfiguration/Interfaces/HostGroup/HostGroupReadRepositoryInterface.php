<?php

/*
 * Copyright 2005 - 2021 Centreon (https://www.centreon.com/)
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * For more information : contact@centreon.com
 *
 */
declare(strict_types=1);

namespace Centreon\Domain\HostConfiguration\Interfaces\HostGroup;

use Centreon\Domain\Contact\Interfaces\ContactInterface;
use Centreon\Domain\HostConfiguration\Model\HostCategory;
use Centreon\Domain\HostConfiguration\Model\HostGroup;

/**
 * This interface gathers all the reading operations on the repository.
 *
 * @package Centreon\Domain\HostConfiguration\Interfaces\HostGroup
 */
interface HostGroupReadRepositoryInterface
{
    /**
     * Find all host groups.
     *
     * @return HostGroup[]
     * @throws \Throwable
     */
    public function findAll(): array;

    /**
     * Find all host groups by contact.
     *
     * @param ContactInterface $contact Contact related to host groups
     * @return HostGroup[]
     * @throws \Throwable
     */
    public function findAllByContact(ContactInterface $contact): array;

    /**
     * Find a host group by id.
     *
     * @param int $hostGroupId Id of the host group to be found
     * @return HostGroup|null
     * @throws \Throwable
     */
    public function findById(int $hostGroupId): ?HostGroup;

    /**
     * Find a host group by id and access groups.
     *
     * @param int $hostGroupId Id of the host group to be found
     * @param ContactInterface $contact Contact related to host categories
     * @return HostGroup|null
     * @throws \Throwable
     */
    public function findByIdAndContact(int $hostGroupId, ContactInterface $contact): ?HostGroup;

    /**
     * Find all host groups.
     *
     * @return HostGroup[]
     */
    public function findHostGroups(): array;
}
