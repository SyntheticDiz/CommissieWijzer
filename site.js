const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");

const workflowContent = {
  pdf: {
    kicker: "STAP 01 · PDF INLEZEN",
    heading: "Begin bij het originele stuk.",
    copy: "Open een pdf met doorzoekbare tekst. CommissieWijzer leest tekst, leesvolgorde en tabellen in. Na import start de analyse automatisch met de provider die je hebt ingesteld.",
    foot: "Je document blijft zichtbaar tijdens het lezen."
  },
  mode: {
    kicker: "STAP 02 · ANALYSEMETHODE",
    heading: "Kies de invalshoek.",
    copy: "Gebruik een neutrale samenvatting of vergelijk met een partijprogramma dat je zelf toevoegt. De keuze bepaalt welke analyse start; programmavergelijking is optioneel.",
    foot: "Jouw instellingen bepalen welke AI-provider wordt gebruikt."
  },
  source: {
    kicker: "STAP 03 · BRON CONTROLEREN",
    heading: "Volg een punt terug naar de passage.",
    copy: "Punten verwijzen naar bronpassages en fysieke pagina’s. Open de passage in de pdf, lees de omliggende tekst en vergelijk uitleg, voorwaarden en bedragen met het oorspronkelijke stuk.",
    foot: "Een bronverwijzing helpt controleren; ze bewijst geen interpretatie."
  },
  keep: {
    kicker: "STAP 04 · BEWAREN EN EXPORTEREN",
    heading: "Bewaar wat jij wilt meenemen.",
    copy: "Voeg eigen notities of passages toe, zoek lokaal en bewaar je werkdocument met pdf, resultaten en leespositie. Exporteer daarna een samenvatting of je selectie als pdf.",
    foot: "Werkdocumenten gebruiken het compatibele .spdfwork-formaat."
  }
};

const workflowButtons = [...document.querySelectorAll("[data-step]")];
const workflowDetail = document.getElementById("workflow-detail");
if (workflowButtons.length && workflowDetail) {
  const kicker = document.getElementById("workflow-kicker");
  const heading = document.getElementById("workflow-heading");
  const copy = document.getElementById("workflow-copy");
  const foot = document.getElementById("workflow-foot");
  let changeTimer;

  function selectWorkflow(button) {
    const item = workflowContent[button.dataset.step];
    if (!item) return;
    workflowButtons.forEach(candidate => {
      const active = candidate === button;
      candidate.classList.toggle("is-active", active);
      candidate.setAttribute("aria-pressed", String(active));
    });
    window.clearTimeout(changeTimer);
    if (!reducedMotion.matches) workflowDetail.classList.add("is-changing");
    changeTimer = window.setTimeout(() => {
      kicker.textContent = item.kicker;
      heading.textContent = item.heading;
      copy.textContent = item.copy;
      foot.textContent = item.foot;
      workflowDetail.classList.remove("is-changing");
    }, reducedMotion.matches ? 0 : 110);
  }

  workflowButtons.forEach(button => button.addEventListener("click", () => selectWorkflow(button)));
}

const sourceContent = {
  purpose: {
    label: "DOEL EN VOORSTEL",
    text: "Het college stelt voor de hoofdingang van de openbare bibliotheek in Voorbeeldstad toegankelijker te maken. Het plan omvat een automatische toegangsdeur, een voelbare en contrasterende looproute naar de balie, en duidelijke routeborden. Dit is een voorstel ter bespreking; er is nog geen krediet toegekend en er is geen opdracht verstrekt."
  },
  costs: {
    label: "VOORGESTELDE UITGAVEN",
    text: "Automatische deur en bediening: € 12.000. Voelbare looproute en contrastmarkering: € 6.500. Routeborden en plaatsing: € 3.500. Totaal aangevraagd: € 22.000 inclusief btw. Dit zijn ramingen, geen offertes."
  },
  decision: {
    label: "GEVRAAGD BESLUIT EN VERANTWOORDELIJKHEID",
    text: "De raad wordt gevraagd op 19 november 2026 te besluiten of maximaal € 22.000 beschikbaar wordt gesteld. Een positief besluit is nog geen opdracht aan een leverancier. Na goedkeuring is het college verantwoordelijk voor inkoop en uitvoering."
  },
  terms: {
    label: "TERMIJN, RISICO’S EN VOORWAARDEN",
    text: "Bij goedkeuring levert het college uiterlijk 15 januari 2027 een uitvoerings- en onderhoudsplan aan de raad. De raming kan afwijken van de offertes. De ingang en vluchtroute moeten tijdens werkzaamheden bruikbaar blijven. Als de offertes samen boven het aangevraagde bedrag uitkomen, vraagt het college eerst een nieuw raadsbesluit aan."
  }
};

const sourceTabs = [...document.querySelectorAll('[role="tab"][data-source]')];
const sourcePanel = document.getElementById("source-panel");
if (sourceTabs.length && sourcePanel) {
  const label = document.getElementById("source-label");
  const text = document.getElementById("source-text");
  let sourceTimer;

  function selectSource(tab, moveFocus = false) {
    const item = sourceContent[tab.dataset.source];
    if (!item) return;
    sourceTabs.forEach(candidate => {
      const active = candidate === tab;
      candidate.setAttribute("aria-selected", String(active));
      candidate.tabIndex = active ? 0 : -1;
    });
    sourcePanel.setAttribute("aria-labelledby", tab.id);
    window.clearTimeout(sourceTimer);
    if (!reducedMotion.matches) sourcePanel.classList.add("is-changing");
    sourceTimer = window.setTimeout(() => {
      label.textContent = item.label;
      text.textContent = item.text;
      sourcePanel.classList.remove("is-changing");
    }, reducedMotion.matches ? 0 : 100);
    if (moveFocus) tab.focus();
  }

  sourceTabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectSource(tab));
    tab.addEventListener("keydown", event => {
      let nextIndex;
      if (event.key === "ArrowRight" || event.key === "ArrowDown") nextIndex = (index + 1) % sourceTabs.length;
      else if (event.key === "ArrowLeft" || event.key === "ArrowUp") nextIndex = (index - 1 + sourceTabs.length) % sourceTabs.length;
      else if (event.key === "Home") nextIndex = 0;
      else if (event.key === "End") nextIndex = sourceTabs.length - 1;
      else return;
      event.preventDefault();
      selectSource(sourceTabs[nextIndex], true);
    });
  });
}

const searchInput = document.getElementById("source-search");
const searchStatus = document.getElementById("search-status");
const sourceResults = [...document.querySelectorAll(".source-result")];
const noResults = document.getElementById("no-results");
if (searchInput && searchStatus && sourceResults.length && noResults) {
  function restoreText(element) {
    if (element.dataset.originalText !== undefined) element.textContent = element.dataset.originalText;
  }

  function addHighlights(element, query) {
    if (element.dataset.originalText === undefined) element.dataset.originalText = element.textContent;
    const original = element.dataset.originalText;
    const lower = original.toLocaleLowerCase("nl-NL");
    const needle = query.toLocaleLowerCase("nl-NL");
    if (!needle) {
      element.textContent = original;
      return;
    }
    const fragment = document.createDocumentFragment();
    let cursor = 0;
    let match = lower.indexOf(needle, cursor);
    while (match !== -1) {
      fragment.append(document.createTextNode(original.slice(cursor, match)));
      const mark = document.createElement("mark");
      mark.textContent = original.slice(match, match + query.length);
      fragment.append(mark);
      cursor = match + query.length;
      match = lower.indexOf(needle, cursor);
    }
    fragment.append(document.createTextNode(original.slice(cursor)));
    element.replaceChildren(fragment);
  }

  function updateSearch() {
    const query = searchInput.value.trim();
    let count = 0;
    sourceResults.forEach(result => {
      const searchable = result.textContent.toLocaleLowerCase("nl-NL");
      const matches = !query || searchable.includes(query.toLocaleLowerCase("nl-NL"));
      result.hidden = !matches;
      result.querySelectorAll("span, p").forEach(element => {
        if (matches && query) addHighlights(element, query);
        else restoreText(element);
      });
      if (matches) count += 1;
    });
    noResults.hidden = count !== 0;
    if (!query) searchStatus.textContent = "Zoeken gebeurt alleen in de vaste fictieve tekst op deze pagina.";
    else searchStatus.textContent = count === 1
      ? "Eén bronfragment gevonden in de fictieve voorbeeldtekst."
      : `${count} bronfragmenten gevonden in de fictieve voorbeeldtekst.`;
  }
  searchInput.addEventListener("input", updateSearch);
}

document.documentElement.classList.add("js");
const revealItems = [...document.querySelectorAll(".reveal")];
if ("IntersectionObserver" in window && !reducedMotion.matches) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      entry.target.classList.add("is-visible");
      observer.unobserve(entry.target);
    });
  }, { threshold: .12, rootMargin: "0px 0px -28px 0px" });
  revealItems.forEach(item => observer.observe(item));
} else {
  revealItems.forEach(item => item.classList.add("is-visible"));
}

reducedMotion.addEventListener?.("change", event => {
  if (!event.matches) return;
  revealItems.forEach(item => item.classList.add("is-visible"));
  document.querySelectorAll(".is-changing").forEach(item => item.classList.remove("is-changing"));
});
