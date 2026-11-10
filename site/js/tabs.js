/* OnRecord tabs: accessible tab switching (WAI-ARIA tabs pattern).
   - Click or tap a tab to switch.
   - Arrow Left/Right move between tabs, Home/End jump to first/last.
   - Only the selected tab is in the Tab order (roving tabindex).
   - Add data-tabs-hash to a .tabs element to enable links like page.html#money. */

(function () {
  function initTabs(root) {
    var list = root.querySelector('[role="tablist"]');
    var tabs = Array.prototype.slice.call(root.querySelectorAll('[role="tab"]'));
    var panels = tabs.map(function (tab) {
      return document.getElementById(tab.getAttribute('aria-controls'));
    });
    var useHash = root.hasAttribute('data-tabs-hash');

    if (!list || tabs.length === 0) return;

    function select(index, options) {
      options = options || {};
      tabs.forEach(function (tab, i) {
        var selected = i === index;
        tab.setAttribute('aria-selected', selected ? 'true' : 'false');
        tab.tabIndex = selected ? 0 : -1;
        if (panels[i]) panels[i].hidden = !selected;
      });
      if (options.focus) tabs[index].focus();
      if (useHash && options.updateHash) {
        history.replaceState(null, '', '#' + tabs[index].id.replace(/^tab-/, ''));
      }
    }

    function indexFromHash() {
      var name = window.location.hash.replace('#', '');
      for (var i = 0; i < tabs.length; i++) {
        if (tabs[i].id === 'tab-' + name) return i;
      }
      return -1;
    }

    tabs.forEach(function (tab, i) {
      tab.addEventListener('click', function () {
        select(i, { updateHash: true });
      });

      tab.addEventListener('keydown', function (event) {
        var next = null;
        if (event.key === 'ArrowRight') next = (i + 1) % tabs.length;
        else if (event.key === 'ArrowLeft') next = (i - 1 + tabs.length) % tabs.length;
        else if (event.key === 'Home') next = 0;
        else if (event.key === 'End') next = tabs.length - 1;
        if (next !== null) {
          event.preventDefault();
          select(next, { focus: true, updateHash: true });
        }
      });
    });

    if (useHash) {
      window.addEventListener('hashchange', function () {
        var i = indexFromHash();
        if (i !== -1) select(i);
      });
    }

    // Progressive enhancement: without JS the tab list stays hidden
    // and every panel shows, stacked. With JS we reveal the list.
    list.hidden = false;
    var start = useHash ? indexFromHash() : -1;
    select(start === -1 ? 0 : start);
  }

  document.addEventListener('DOMContentLoaded', function () {
    var groups = document.querySelectorAll('[data-tabs]');
    Array.prototype.forEach.call(groups, initTabs);
  });
})();
