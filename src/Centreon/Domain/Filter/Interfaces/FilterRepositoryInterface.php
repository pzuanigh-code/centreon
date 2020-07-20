<?php

/*
 * Copyright 2005 - 2020 Centreon (https://www.centreon.com/)
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

namespace Centreon\Domain\Filter\Interfaces;

use Centreon\Domain\Filter\Filter;
use Centreon\Domain\Filter\FilterException;

interface FilterRepositoryInterface
{
    /**
     * Add filter.
     *
     * @param Filter $filter
     * @return int created filter id
     * @throws FilterException
     */
    public function addFilter(Filter $filter): int;

    /**
     * Update filter.
     *
     * @param Filter $filter
     * @return void
     * @throws FilterException
     */
    public function updateFilter(Filter $filter): void;

    /**
     * Delete filter.
     *
     * @param Filter $filter
     * @return void
     * @throws FilterException
     */
    public function deleteFilter(Filter $filter): void;

    /**
     * Find filters linked to a user id using request parameters.
     *
     * @param int $userId current user id
     * @return Filter[]
     * @throws \Exception
     */
    public function findFiltersByUserIdWithRequestParameters(int $userId, string $pageName): array;

    /**
     * Find filters linked to a user id without using request parameters.
     *
     * @param int $userId current user id
     * @param string $pageName page name
     * @return Filter[]
     * @throws \Exception
     */
    public function findFiltersByUserIdWithoutRequestParameters(int $userId, string $pageName): array;

    /**
     * Find filter by id
     *
     * @param integer $userId
     * @param string $pageName
     * @param string $name
     * @return Filter|null
     */
    public function findFilterByUserIdAndName(int $userId, string $pageName, string $name): ?Filter;

    /**
     * Find filter by user id and filter id.
     *
     * @param int $userId current user id
     * @param string $pageName page name
     * @param int $filterId Filter id to search
     * @return Filter
     * @throws FilterException
     */
    public function findFilterByUserIdAndId(int $userId, string $pageName, int $filterId): ?Filter;
}
