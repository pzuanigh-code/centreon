import * as React from 'react';

import { Skeleton } from '@material-ui/lab';

const FilterLoadingSkeleton = (): JSX.Element => {
  return <Skeleton height="100%" width={200} style={{ transform: 'none' }} />;
};

export default FilterLoadingSkeleton;
