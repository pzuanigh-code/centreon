import * as React from 'react';

import { ParentSize } from '@visx/visx';
import { map, prop, propEq, find, reject, sortBy, isEmpty, isNil } from 'ramda';
import { useTranslation } from 'react-i18next';

import {
  makeStyles,
  Typography,
  Theme,
  FormControlLabel,
  Switch,
} from '@material-ui/core';

import { useRequest, getData, timeFormat } from '@centreon/ui';

import {
  labelNoDataForThisPeriod,
  labelEventAnnotations,
} from '../../translatedLabels';
import { TimelineEvent } from '../../Details/tabs/Timeline/models';
import { Resource } from '../../models';
import { ResourceDetails } from '../../Details/models';
import { CommentParameters } from '../../Actions/api';

import Graph from './Graph';
import Legend from './Legend';
import LoadingSkeleton from './LoadingSkeleton';
import { GraphData, TimeValue, Line as LineModel } from './models';
import { getTimeSeries, getLineData } from './timeSeries';

interface Props {
  endpoint?: string;
  xAxisTickFormat?: string;
  graphHeight: number;
  toggableLegend?: boolean;
  onAddComment: (comment: CommentParameters) => void;
  resource: Resource | ResourceDetails;
  timeline?: Array<TimelineEvent>;
}

const useStyles = makeStyles<Theme, Pick<Props, 'graphHeight'>>((theme) => ({
  container: {
    display: 'grid',
    flexDirection: 'column',
    gridTemplateRows: ({ graphHeight }): string =>
      `auto ${graphHeight}px auto auto`,
    gridGap: theme.spacing(1),
    height: '100%',
    justifyItems: 'center',
  },
  noDataContainer: {
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    height: '100%',
  },
  legend: {
    display: 'flex',
    flexWrap: 'wrap',
    justifyContent: 'center',
    alignItems: 'center',
    width: '100%',
  },
}));

const PerformanceGraph = ({
  endpoint,
  graphHeight,
  xAxisTickFormat = timeFormat,
  toggableLegend = false,
  onAddComment,
  resource,
  timeline,
}: Props): JSX.Element | null => {
  const classes = useStyles({ graphHeight });
  const { t } = useTranslation();

  const [timeSeries, setTimeSeries] = React.useState<Array<TimeValue>>([]);
  const [lineData, setLineData] = React.useState<Array<LineModel>>([]);
  const [title, setTitle] = React.useState<string>();
  const [base, setBase] = React.useState<number>();
  const [eventAnnotationsActive, setEventAnnotationsActive] = React.useState(
    false,
  );

  const {
    sendRequest: sendGetGraphDataRequest,
    sending: sendingGetGraphDataRequest,
  } = useRequest<GraphData>({
    request: getData,
  });

  React.useEffect(() => {
    if (isNil(endpoint)) {
      return;
    }

    sendGetGraphDataRequest(endpoint).then((graphData) => {
      setTimeSeries(getTimeSeries(graphData));
      setLineData(getLineData(graphData));
      setTitle(graphData.global.title);
      setBase(graphData.global.base);
    });
  }, [endpoint]);

  const loading =
    sendingGetGraphDataRequest || isNil(timeline) || isNil(endpoint);

  if (loading) {
    return <LoadingSkeleton />;
  }

  if (isEmpty(timeSeries) || isEmpty(lineData)) {
    return (
      <div className={classes.noDataContainer}>
        <Typography align="center" variant="body1">
          {t(labelNoDataForThisPeriod)}
        </Typography>
      </div>
    );
  }

  const sortedLines = sortBy(prop('name'), lineData);
  const displayedLines = reject(propEq('display', false), sortedLines);

  const getLineByMetric = (metric): LineModel => {
    return find(propEq('metric', metric), lineData) as LineModel;
  };

  const toggleMetricDisplay = (metric): void => {
    const line = getLineByMetric(metric);

    setLineData([
      ...reject(propEq('metric', metric), lineData),
      { ...line, display: !line.display },
    ]);
  };

  const highlightLine = (metric): void => {
    const fadedLines = map((line) => ({ ...line, highlight: false }), lineData);

    setLineData([
      ...reject(propEq('metric', metric), fadedLines),
      { ...getLineByMetric(metric), highlight: true },
    ]);
  };

  const clearHighlight = (): void => {
    setLineData(map((line) => ({ ...line, highlight: undefined }), lineData));
  };

  const changeEventAnnotationsActive = (
    event: React.ChangeEvent<HTMLInputElement>,
  ): void => {
    setEventAnnotationsActive(event.target.checked);
  };

  return (
    <div className={classes.container}>
      <Typography variant="body1" color="textPrimary">
        {title}
      </Typography>

      <ParentSize>
        {({ width, height }): JSX.Element => (
          <Graph
            width={width}
            height={height}
            timeSeries={timeSeries}
            lines={displayedLines}
            base={base as number}
            xAxisTickFormat={xAxisTickFormat}
            timeline={timeline}
            resource={resource}
            onAddComment={onAddComment}
            eventAnnotationsActive={eventAnnotationsActive}
          />
        )}
      </ParentSize>
      <div>
        <FormControlLabel
          control={
            <Switch
              color="primary"
              size="small"
              onChange={changeEventAnnotationsActive}
            />
          }
          label={
            <Typography variant="body2">{labelEventAnnotations}</Typography>
          }
        />
      </div>
      <div className={classes.legend}>
        <Legend
          lines={sortedLines}
          onItemToggle={toggleMetricDisplay}
          toggable={toggableLegend}
          onItemHighlight={highlightLine}
          onClearItemHighlight={clearHighlight}
        />
      </div>
    </div>
  );
};

export default PerformanceGraph;
