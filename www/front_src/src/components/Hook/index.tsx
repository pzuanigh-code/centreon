import * as React from 'react';

import { connect } from 'react-redux';
import { withRouter } from 'react-router-dom';
import { equals } from 'ramda';

import { dynamicImport } from '../../helpers/dynamicImport';
import centreonAxios from '../../axios';
import MenuLoader from '../header/menuLoader';

interface Props {
  history;
  hooks;
  path;
}

const LoadableHooks = ({
  history,
  hooks,
  path,
  ...rest
}: Props): JSX.Element => {
  const basename = history.createHref({
    pathname: '/',
    search: '',
    hash: '',
  });

  return (
    <>
      {Object.entries(hooks)
        .filter(([hook]) => hook.includes(path))
        .map(([, parameters]) => {
          const HookComponent = React.lazy(() =>
            dynamicImport(basename, parameters),
          );

          return (
            <React.Suspense key={path} fallback={<MenuLoader width={29} />}>
              <HookComponent centreonAxios={centreonAxios} {...rest} />
            </React.Suspense>
          );
        })}
    </>
  );
};

const Hook = React.memo(
  (props: Props) => {
    return <LoadableHooks {...props} />;
  },
  ({ hooks: previousHooks }, { hooks: nextHooks }) =>
    equals(previousHooks, nextHooks),
);

const mapStateToProps = ({ externalComponents }): Record<string, unknown> => ({
  hooks: externalComponents.hooks,
});

export default connect(mapStateToProps)(withRouter(Hook));
