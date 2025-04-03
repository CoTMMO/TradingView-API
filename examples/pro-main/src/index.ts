/**
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at

 * http://www.apache.org/licenses/LICENSE-2.0

 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { registerOverlay } from 'klinecharts'

import overlays from './extension'

import DefaultDatafeed from './DefaultDatafeed'
import KLineChartPro from './KLineChartPro'

import { load } from './i18n'

import { Datafeed, SymbolInfo, Period, DatafeedSubscribeCallback, ChartProOptions, ChartPro } from './types'

import './index.less'

overlays.forEach(o => { registerOverlay(o) })

// Note: If you need to export a React component, consider moving it to a separate .tsx file
// or rename this file to index.tsx if it's meant to contain JSX code

export {
  DefaultDatafeed,
  KLineChartPro,
  load as loadLocales
}

export type {
  Datafeed, SymbolInfo, Period, DatafeedSubscribeCallback, ChartProOptions, ChartPro
}

// If you need to create a React component, it should be in a .tsx file:
// export const Chart = ({ chartProOptions, onChartReady }) => {
//   let chartPro;
//   return (
//     <KLineChartPro
//       {...chartProOptions}
//       ref={(chart) => { 
//         chartPro = chart;
//         if (onChartReady) onChartReady(chartPro);
//       }}
//     />
//   );
// };
