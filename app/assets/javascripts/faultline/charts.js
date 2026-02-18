// Faultline dashboard JavaScript
// All chart data is read from data-* attributes on canvas elements so that
// no Ruby-generated JSON is embedded inside <script> blocks. This allows
// the host application to enforce a strict Content-Security-Policy without
// requiring 'unsafe-inline' for script-src.

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

(function () {
  if (localStorage.getItem('faultline-theme') === 'light') {
    document.documentElement.classList.remove('dark');
  }
})();

window.toggleTheme = function () {
  const html = document.documentElement;
  if (html.classList.contains('dark')) {
    html.classList.remove('dark');
    localStorage.setItem('faultline-theme', 'light');
  } else {
    html.classList.add('dark');
    localStorage.setItem('faultline-theme', 'dark');
  }
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function parseAttr(canvas, attr) {
  const raw = canvas.dataset[attr];
  if (!raw) return null;
  try { return JSON.parse(raw); } catch (e) { return null; }
}

function gridColor() {
  return 'rgba(148, 163, 184, 0.1)';
}

function initChart(id, fn) {
  const canvas = document.getElementById(id);
  if (canvas) fn(canvas);
}

// ---------------------------------------------------------------------------
// Response time line chart  (performance/index + performance/show)
// data-labels, data-avg, data-max
// ---------------------------------------------------------------------------

function initResponseTimeChart(canvas) {
  const labels = parseAttr(canvas, 'labels') || [];
  const avg    = parseAttr(canvas, 'avg')    || [];
  const max    = parseAttr(canvas, 'max')    || [];

  new Chart(canvas.getContext('2d'), {
    type: 'line',
    data: {
      labels,
      datasets: [
        {
          label: 'Avg',
          data: avg,
          borderColor: '#22d3ee',
          backgroundColor: 'rgba(34, 211, 238, 0.1)',
          fill: true,
          tension: 0.3,
          borderWidth: 2,
          pointRadius: 1
        },
        {
          label: 'Max',
          data: max,
          borderColor: '#f59e0b',
          backgroundColor: 'transparent',
          borderDash: [4, 4],
          tension: 0.3,
          borderWidth: 1.5,
          pointRadius: 0
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      interaction: { mode: 'index', intersect: false },
      plugins: {
        legend: { display: false },
        tooltip: {
          callbacks: {
            label: function (ctx) {
              return ctx.dataset.label + ': ' + ctx.raw.toFixed(1) + 'ms';
            }
          }
        }
      },
      scales: {
        y: {
          beginAtZero: true,
          grid: { color: gridColor() },
          ticks: { callback: function (v) { return v + 'ms'; } }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Throughput bar chart  (performance/index)
// data-labels, data-values
// ---------------------------------------------------------------------------

function initThroughputChart(canvas) {
  const labels = parseAttr(canvas, 'labels') || [];
  const values = parseAttr(canvas, 'values') || [];

  new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'Requests',
        data: values,
        backgroundColor: 'rgba(244, 63, 94, 0.6)',
        borderColor: '#f43f5e',
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { stepSize: 1 },
          grid: { color: gridColor() }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Error overview bar chart  (error_groups/index)
// data-labels, data-values
// ---------------------------------------------------------------------------

function initOverviewChart(canvas) {
  const labels = parseAttr(canvas, 'labels') || [];
  const values = parseAttr(canvas, 'values') || [];

  new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'Occurrences',
        data: values,
        backgroundColor: 'rgba(34, 211, 238, 0.6)',
        borderColor: '#22d3ee',
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { stepSize: 1 },
          grid: { color: gridColor() }
        },
        x: { grid: { display: false } }
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Occurrences detail bar chart with zoom  (error_groups/show)
// data-labels, data-values, data-timestamps, data-can-zoom,
// data-zoom-interval, data-base-url, data-period
// ---------------------------------------------------------------------------

function initOccurrencesChart(canvas) {
  const labels      = parseAttr(canvas, 'labels')     || [];
  const values      = parseAttr(canvas, 'values')     || [];
  const timestamps  = parseAttr(canvas, 'timestamps') || [];
  const canZoom     = canvas.dataset.canZoom === 'true';
  const zoomInterval = parseInt(canvas.dataset.zoomInterval || '0', 10);
  const baseUrl     = canvas.dataset.baseUrl  || '';
  const period      = canvas.dataset.period   || '';

  new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      datasets: [{
        label: 'Occurrences',
        data: values,
        backgroundColor: 'rgba(34, 211, 238, 0.6)',
        borderColor: '#22d3ee',
        borderWidth: 1,
        borderRadius: 4
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        y: {
          beginAtZero: true,
          ticks: { stepSize: 1 },
          grid: { color: gridColor() }
        },
        x: { grid: { display: false } }
      },
      onClick: function (event, elements) {
        if (canZoom && elements.length > 0) {
          const index      = elements[0].index;
          const clickedTime = new Date(timestamps[index]);
          const zoomEnd    = new Date(clickedTime.getTime() + zoomInterval);
          window.location  = baseUrl + '?period=' + period +
            '&zoom_start=' + clickedTime.toISOString() +
            '&zoom_end='   + zoomEnd.toISOString();
        }
      },
      onHover: function (event, elements) {
        if (canZoom) {
          event.native.target.style.cursor = elements.length ? 'pointer' : 'default';
        }
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

document.addEventListener('DOMContentLoaded', function () {
  initChart('responseTimeChart', initResponseTimeChart);
  initChart('endpointChart',     initResponseTimeChart);
  initChart('throughputChart',   initThroughputChart);
  initChart('overviewChart',     initOverviewChart);
  initChart('occurrencesChart',  initOccurrencesChart);
});
