// SPARK coverage panel: sort the per-group table by clicking a column
// header, and keep the table readable when there are many rows.
(function () {
  function sortSparkTable(th) {
    var table = th.closest('table');
    var body = table.tBodies[0];
    if (!body) {
      var rows = Array.prototype.slice.call(table.rows, 1);
      body = table.createTBody();
      rows.forEach(function (r) { body.appendChild(r); });
    }
    var idx = th.cellIndex;
    var asc = th.getAttribute('data-asc') !== '1';
    Array.prototype.slice.call(body.rows)
      .sort(function (a, b) {
        var x = a.cells[idx].textContent;
        var y = b.cells[idx].textContent;
        var nx = parseFloat(x);
        var ny = parseFloat(y);
        if (!isNaN(nx) && !isNaN(ny)) { return asc ? nx - ny : ny - nx; }
        return asc ? x.localeCompare(y) : y.localeCompare(x);
      })
      .forEach(function (r) { body.appendChild(r); });
    th.setAttribute('data-asc', asc ? '1' : '0');
  }
  document.querySelectorAll('table.spark-table th').forEach(function (th) {
    th.style.cursor = 'pointer';
    th.addEventListener('click', function () { sortSparkTable(th); });
  });
})();
