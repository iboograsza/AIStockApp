import SwiftUI
import WebKit

// MARK: - KLine WebView (TradingView Lightweight Charts)
struct KLineChartView: UIViewRepresentable {
    let data: [KLineData]
    let stockName: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = UIColor.black
        webView.scrollView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = buildHTML()
        webView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {}

    // MARK: - Build HTML with inline JS chart
    private func buildHTML() -> String {
        let candleJSON = buildCandleJSON()
        let volumeJSON = buildVolumeJSON()
        let ma5JSON = buildMAJSON(period: 5)
        let ma10JSON = buildMAJSON(period: 10)
        let ma20JSON = buildMAJSON(period: 20)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body { background: #0d0d0d; color: #fff; font-family: -apple-system, sans-serif; overflow: hidden; }
          #chart-container { width: 100vw; display: flex; flex-direction: column; }
          #main-chart { width: 100%; height: 68vh; }
          #vol-chart  { width: 100%; height: 22vh; border-top: 1px solid #222; }
          #legend {
            position: absolute; top: 4px; left: 6px; right: 6px;
            display: flex; gap: 12px; align-items: center;
            font-size: 11px; pointer-events: none; z-index: 10;
          }
          .leg-item { display: flex; align-items: center; gap: 4px; }
          .leg-dot  { width: 8px; height: 8px; border-radius: 50%; }
          #ohlc-info {
            position: absolute; top: 20px; left: 6px;
            font-size: 11px; color: #aaa; pointer-events: none; z-index: 10;
          }
        </style>
        </head>
        <body>
        <div id="chart-container">
          <div style="position:relative;">
            <div id="legend">
              <span style="color:#fff;font-size:12px;font-weight:600;">\(stockName)</span>
              <div class="leg-item"><div class="leg-dot" style="background:#ff5f5f;"></div><span style="color:#ff9999;">MA5</span></div>
              <div class="leg-item"><div class="leg-dot" style="background:#ffd700;"></div><span style="color:#ffd700;">MA10</span></div>
              <div class="leg-item"><div class="leg-dot" style="background:#00cfff;"></div><span style="color:#00cfff;">MA20</span></div>
            </div>
            <div id="ohlc-info"></div>
            <div id="main-chart"></div>
          </div>
          <div id="vol-chart"></div>
        </div>

        <script src="https://unpkg.com/lightweight-charts/dist/lightweight-charts.standalone.production.js"></script>
        <script>
        (function() {
          // ---- Data ----
          var candleData  = \(candleJSON);
          var volumeData  = \(volumeJSON);
          var ma5Data     = \(ma5JSON);
          var ma10Data    = \(ma10JSON);
          var ma20Data    = \(ma20JSON);

          // ---- Main chart ----
          var mainChart = LightweightCharts.createChart(document.getElementById('main-chart'), {
            width: window.innerWidth,
            height: Math.floor(window.innerHeight * 0.68),
            layout: { background: { color: '#0d0d0d' }, textColor: '#888' },
            grid: { vertLines: { color: '#1a1a1a' }, horzLines: { color: '#1a1a1a' } },
            crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
            rightPriceScale: { borderColor: '#333', scaleMargins: { top: 0.06, bottom: 0.02 } },
            timeScale: { borderColor: '#333', timeVisible: true, secondsVisible: false }
          });

          var candleSeries = mainChart.addCandlestickSeries({
            upColor: '#eb4d4b',
            downColor: '#26a69a',
            borderUpColor: '#eb4d4b',
            borderDownColor: '#26a69a',
            wickUpColor: '#eb4d4b',
            wickDownColor: '#26a69a'
          });
          candleSeries.setData(candleData);

          var ma5Series = mainChart.addLineSeries({ color: '#ff5f5f', lineWidth: 1, priceLineVisible: false, lastValueVisible: false });
          ma5Series.setData(ma5Data);

          var ma10Series = mainChart.addLineSeries({ color: '#ffd700', lineWidth: 1, priceLineVisible: false, lastValueVisible: false });
          ma10Series.setData(ma10Data);

          var ma20Series = mainChart.addLineSeries({ color: '#00cfff', lineWidth: 1, priceLineVisible: false, lastValueVisible: false });
          ma20Series.setData(ma20Data);

          mainChart.timeScale().fitContent();

          // ---- Volume chart ----
          var volChart = LightweightCharts.createChart(document.getElementById('vol-chart'), {
            width: window.innerWidth,
            height: Math.floor(window.innerHeight * 0.22),
            layout: { background: { color: '#0d0d0d' }, textColor: '#555' },
            grid: { vertLines: { color: '#111' }, horzLines: { color: '#111' } },
            crosshair: { mode: LightweightCharts.CrosshairMode.Normal },
            rightPriceScale: {
              borderColor: '#333',
              scaleMargins: { top: 0.1, bottom: 0.0 },
              minimumWidth: 60
            },
            timeScale: { visible: false }
          });

          var volSeries = volChart.addHistogramSeries({
            priceFormat: { type: 'volume' },
            priceScaleId: 'right',
            scaleMargins: { top: 0.1, bottom: 0 }
          });
          volSeries.setData(volumeData);
          volChart.timeScale().fitContent();

          // ---- Sync crosshair ----
          mainChart.timeScale().subscribeVisibleLogicalRangeChange(function(range) {
            volChart.timeScale().setVisibleLogicalRange(range);
          });
          volChart.timeScale().subscribeVisibleLogicalRangeChange(function(range) {
            mainChart.timeScale().setVisibleLogicalRange(range);
          });

          // ---- OHLC tooltip ----
          var ohlcEl = document.getElementById('ohlc-info');
          mainChart.subscribeCrosshairMove(function(param) {
            if (!param || !param.seriesData) return;
            var d = param.seriesData.get(candleSeries);
            if (!d) return;
            var upClr = '#eb4d4b', dnClr = '#26a69a';
            var c = d.close >= d.open ? upClr : dnClr;
            ohlcEl.innerHTML =
              'O:<span style="color:' + c + '">' + d.open.toFixed(2) + '</span> ' +
              'H:<span style="color:' + c + '">' + d.high.toFixed(2) + '</span> ' +
              'L:<span style="color:' + c + '">' + d.low.toFixed(2) + '</span> ' +
              'C:<span style="color:' + c + '">' + d.close.toFixed(2) + '</span>';
          });

          // ---- Resize ----
          window.addEventListener('resize', function() {
            mainChart.resize(window.innerWidth, Math.floor(window.innerHeight * 0.68));
            volChart.resize(window.innerWidth, Math.floor(window.innerHeight * 0.22));
          });
        })();
        </script>
        </body>
        </html>
        """
    }

    // MARK: - JSON Builders
    private func dateString(_ d: KLineData) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: d.date)
    }

    private func buildCandleJSON() -> String {
        let items = data.map { k in
            """
            {"time":"\(dateString(k))","open":\(k.open),"high":\(k.high),"low":\(k.low),"close":\(k.close)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    private func buildVolumeJSON() -> String {
        let items = data.map { k -> String in
            let color = k.close >= k.open ? "'#eb4d4b'" : "'#26a69a'"
            return """
            {"time":"\(dateString(k))","value":\(k.volume),"color":\(color)}
            """
        }
        return "[\(items.joined(separator: ","))]"
    }

    private func buildMAJSON(period: Int) -> String {
        var result: [String] = []
        for i in (period - 1)..<data.count {
            let slice = data[(i - period + 1)...i]
            let avg = slice.map { $0.close }.reduce(0, +) / Double(period)
            let rounded = (avg * 100).rounded() / 100
            result.append("""
            {"time":"\(dateString(data[i]))","value":\(rounded)}
            """)
        }
        return "[\(result.joined(separator: ","))]"
    }
}
