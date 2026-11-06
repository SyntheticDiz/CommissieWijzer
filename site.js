(() => {
  const motionPreference = window.matchMedia("(prefers-reduced-motion: reduce)");
  const root = document.documentElement;
  const demo = document.querySelector(".demo-sticky");
  const frame = document.getElementById("demo-capture-frame");
  const storyImages = [document.getElementById("demo-capture"), document.getElementById("demo-capture-next")];
  const caption = document.getElementById("demo-caption-text");
  const fullShotLink = document.getElementById("full-shot-link");
  const storySteps = [...document.querySelectorAll("[data-story-step]")];
  const stepButtons = [...document.querySelectorAll("[data-demo-step]")];
  const playButton = document.getElementById("play-demo");
  const story = [
    {
      src: "WebsiteAssets/documentpunten.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer: documentpunten links en de fictieve voorbeeld-pdf rechts.",
      caption: "Documentpunten naast de originele voorbeeld-pdf.",
      href: "WebsiteAssets/documentpunten.jpg"
    },
    {
      src: "WebsiteAssets/bronpassage.jpg",
      fallbackSrc: "WebsiteAssets/documentpunten.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met de gevonden bronpassage uit het fictieve raadsvoorstel.",
      caption: "De gevonden bronpassage in context; echte appweergave.",
      href: "WebsiteAssets/bronpassage.jpg",
      fallbackAlt: "Echte appweergave met documentpunten en de fictieve voorbeeld-pdf; de aparte bronpassage-opname wordt niet geladen.",
      fallbackCaption: "Echte appweergave met het document en de gekoppelde punten.",
      fallbackHref: "WebsiteAssets/documentpunten.jpg"
    },
    {
      src: "WebsiteAssets/selectie-notities.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met Mijn selectie en een voorbeeldnotitie bij een fictief raadsvoorstel.",
      caption: "Mijn selectie en voorbeeldnotitie in de echte app.",
      href: "WebsiteAssets/selectie-notities.jpg"
    },
    {
      src: "WebsiteAssets/lokaal-zoeken.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met lokale zoekresultaten in een fictief raadsvoorstel.",
      caption: "Zoekresultaten in de echte app.",
      href: "WebsiteAssets/lokaal-zoeken.jpg"
    }
  ];

  let selectedStep = 0;
  let activeStoryImage = 0;
  let storyRequest = 0;
  let storyFadeTimer = 0;
  let playbackTimer = 0;

  function setPlaybackButton() {
    if (!playButton) return;
    const reduced = motionPreference.matches;
    const playing = Boolean(playbackTimer);
    playButton.disabled = reduced;
    playButton.setAttribute("aria-pressed", String(playing));
    playButton.setAttribute("aria-label", reduced
      ? "Automatisch afspelen uitgeschakeld door de bewegingsvoorkeur"
      : playing ? "Pauzeer appbeelden" : "Speel appbeelden automatisch af");
    const label = playButton.querySelector(".play-label");
    const icon = playButton.querySelector("span:first-child");
    if (label) label.textContent = reduced ? "Animatie uit" : playing ? "Pauzeer" : "Speel stappen";
    if (icon) icon.textContent = playing ? "Ⅱ" : "▶";
  }

  function stopPlayback() {
    if (playbackTimer) window.clearInterval(playbackTimer);
    playbackTimer = 0;
    setPlaybackButton();
  }

  function setStoryCapture(item, step) {
    const token = ++storyRequest;
    if (storyFadeTimer) window.clearTimeout(storyFadeTimer);
    const active = storyImages[activeStoryImage];
    const incomingIndex = 1 - activeStoryImage;
    const incoming = storyImages[incomingIndex];
    active.classList.add("is-active");
    incoming.classList.remove("is-active");
    incoming.setAttribute("aria-hidden", "true");
    incoming.alt = "";
    frame.dataset.step = String(step);

    incoming.onload = () => {
      if (token !== storyRequest) return;
      incoming.onerror = null;
      incoming.alt = item.alt;
      incoming.removeAttribute("aria-hidden");
      active.setAttribute("aria-hidden", "true");
      if (motionPreference.matches) {
        active.classList.remove("is-active");
        incoming.classList.add("is-active");
        activeStoryImage = incomingIndex;
      } else {
        window.requestAnimationFrame(() => {
          if (token !== storyRequest) return;
          incoming.classList.add("is-active");
          active.classList.remove("is-active");
          activeStoryImage = incomingIndex;
          storyFadeTimer = window.setTimeout(() => {
            if (token === storyRequest) active.classList.remove("is-active");
          }, 1200);
        });
      }
      caption.textContent = item.caption;
      fullShotLink.href = item.href;
    };
    incoming.onerror = () => {
      if (token !== storyRequest) return;
      incoming.onload = null;
      incoming.onerror = null;
      if (item.fallbackSrc) {
        setStoryCapture({
          src: item.fallbackSrc,
          alt: item.fallbackAlt,
          caption: item.fallbackCaption,
          href: item.fallbackHref
        }, step);
      }
    };
    incoming.src = item.src;
  }

  function setStep(step, source = "manual") {
    if (!Number.isInteger(step) || step < 0 || step >= story.length) return;
    if (source === "manual") stopPlayback();
    selectedStep = step;
    setStoryCapture(story[step], step);
    stepButtons.forEach((button, index) => {
      const active = index === step;
      button.classList.toggle("is-active", active);
      button.setAttribute("aria-pressed", String(active));
    });
    storySteps.forEach((element, index) => element.classList.toggle("is-current", index === step));
  }
  stepButtons.forEach(button => button.addEventListener("click", () => setStep(Number(button.dataset.demoStep))));

  function elementIsVisible(element) {
    const rect = element.getBoundingClientRect();
    return rect.bottom > 0 && rect.top < window.innerHeight && rect.right > 0 && rect.left < window.innerWidth;
  }
  function startPlayback() {
    if (motionPreference.matches || !demo || !elementIsVisible(demo) || playbackTimer) return;
    playbackTimer = window.setInterval(() => setStep((selectedStep + 1) % story.length, "playback"), 4200);
    setPlaybackButton();
  }
  playButton?.addEventListener("click", () => playbackTimer ? stopPlayback() : startPlayback());

  if (demo && "IntersectionObserver" in window) {
    const demoObserver = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting || entry.intersectionRatio <= .22) stopPlayback();
    }, { threshold: [0, .22, .5] });
    demoObserver.observe(demo);
  }

  window.addEventListener("wheel", stopPlayback, { passive: true });
  document.addEventListener("pointerdown", event => {
    if (playbackTimer && !playButton?.contains(event.target)) stopPlayback();
  }, { passive: true });
  document.addEventListener("keydown", event => {
    const playbackActivation = playButton?.contains(event.target) && [" ", "Enter"].includes(event.key);
    if (!playbackActivation && ["ArrowDown", "ArrowUp", "PageDown", "PageUp", "Home", "End", " "].includes(event.key)) stopPlayback();
  });
  document.addEventListener("visibilitychange", () => { if (document.hidden) stopPlayback(); });
  motionPreference.addEventListener?.("change", () => {
    stopPlayback();
    setPlaybackButton();
  });
  setPlaybackButton();

  const sourceCapture = document.getElementById("source-capture");
  const sourceLink = document.getElementById("source-full-shot-link");
  if (sourceCapture && sourceLink) {
    sourceCapture.onerror = () => {
      sourceCapture.onerror = null;
      sourceCapture.src = "WebsiteAssets/documentpunten.jpg";
      sourceCapture.width = 2560;
      sourceCapture.height = 1680;
      sourceCapture.alt = "Echte schermafbeelding van CommissieWijzer met documentpunten en de fictieve voorbeeld-pdf; de aparte bronpassage-opname wordt niet geladen.";
      sourceLink.href = "WebsiteAssets/documentpunten.jpg";
    };
  }

  const featureData = {
    search: {
      kicker: "LEZEN · LOKAAL",
      title: "Zoek in de tekst die jij hebt geopend.",
      copy: "Zoeken doorzoekt lokaal de pdf-tekst en beschikbare analyse, resultaten en notities. Resultaten verwijzen terug naar de relevante pagina.",
      href: "WebsiteAssets/lokaal-zoeken.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met lokale zoekresultaten in een fictief document.",
      caption: "Echte appweergave · lokaal zoeken in een fictief document.",
      link: "support.html#scan",
      linkLabel: "Meer over pdf-inlezen"
    },
    notes: {
      kicker: "VOORBEREIDEN · EIGEN NOTITIES",
      title: "Zet je eigen vragen bij het stuk.",
      copy: "Selecteer aandachtspunten en voeg je eigen notities toe. Bewaar de voorbereiding met het document op je Mac.",
      href: "WebsiteAssets/selectie-notities.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met Mijn selectie en een voorbeeldnotitie bij een fictief raadsvoorstel.",
      caption: "Echte appweergave · selectie en notitie bij fictieve inhoud.",
      link: "support.html#werk",
      linkLabel: "Meer over werkdocumenten"
    },
    program: {
      kicker: "OPTIONEEL · EIGEN KADER",
      title: "Vergelijk alleen als jij dat wilt.",
      copy: "Een neutrale samenvatting gebruikt geen partijprogramma. Voor vergelijking kies je zelf een programma. Dat is een analyse-instelling, geen aanbeveling of politieke aansluiting.",
      href: "WebsiteAssets/documentpunten.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met documentpunten naast een fictief raadsvoorstel.",
      caption: "Echte appweergave · de webpagina voert geen programmavergelijking uit.",
      link: "privacy.html#chatgpt",
      linkLabel: "Bekijk de privacyuitleg"
    },
    export: {
      kicker: "BEWAREN · PDF-EXPORT",
      title: "Neem je selectie mee.",
      copy: "Bewaar het werkdocument op je Mac of exporteer een samenvatting of selectie als pdf. Controleer de inhoud voordat je die deelt.",
      href: "WebsiteAssets/exporteren.jpg",
      alt: "Echte schermafbeelding van CommissieWijzer met het exportscherm en de geselecteerde onderdelen Mijn selectie en Bronnenbijlage.",
      caption: "Echte appweergave · gekozen onderdelen voor pdf-export.",
      width: 2560,
      height: 1680,
      link: "support.html#werk",
      linkLabel: "Meer over bewaren en exporteren"
    }
  };
  const featureTabs = [...document.querySelectorAll("[data-feature]")];
  const featureImages = [document.getElementById("feature-capture"), document.getElementById("feature-capture-next")];
  const featureLink = document.getElementById("feature-full-shot-link");
  let activeFeatureImage = 0;
  let featureRequest = 0;
  let featureFadeTimer = 0;

  function updateFeatureText(tab, details) {
    document.getElementById("feature-panel").setAttribute("aria-labelledby", tab.id);
    document.getElementById("feature-kicker").textContent = details.kicker;
    document.getElementById("feature-title").textContent = details.title;
    document.getElementById("feature-copy").textContent = details.copy;
    document.getElementById("feature-caption").textContent = details.caption;
    const link = document.getElementById("feature-link");
    link.href = details.link;
    link.innerHTML = `${details.linkLabel} <span aria-hidden="true">↗</span>`;
  }

  function selectFeature(tab, focus = false) {
    const details = featureData[tab.dataset.feature];
    if (!details) return;
    featureTabs.forEach(candidate => {
      const selected = candidate === tab;
      candidate.setAttribute("aria-selected", String(selected));
      candidate.tabIndex = selected ? 0 : -1;
    });
    if (featureFadeTimer) window.clearTimeout(featureFadeTimer);
    const token = ++featureRequest;
    const active = featureImages[activeFeatureImage];
    const incomingIndex = 1 - activeFeatureImage;
    const incoming = featureImages[incomingIndex];
    active.classList.add("is-active");
    incoming.classList.remove("is-active");
    incoming.setAttribute("aria-hidden", "true");
    incoming.alt = "";
    incoming.onload = () => {
      if (token !== featureRequest) return;
      incoming.onerror = null;
      incoming.alt = details.alt;
      incoming.removeAttribute("aria-hidden");
      active.setAttribute("aria-hidden", "true");
      if (motionPreference.matches) {
        active.classList.remove("is-active");
        incoming.classList.add("is-active");
        activeFeatureImage = incomingIndex;
      } else {
        window.requestAnimationFrame(() => {
          if (token !== featureRequest) return;
          incoming.classList.add("is-active");
          active.classList.remove("is-active");
          activeFeatureImage = incomingIndex;
          featureFadeTimer = window.setTimeout(() => {
            if (token === featureRequest) active.classList.remove("is-active");
          }, 1200);
        });
      }
      featureLink.href = details.href;
      updateFeatureText(tab, details);
    };
    incoming.onerror = () => {
      if (token !== featureRequest) return;
      incoming.onerror = null;
      incoming.onload = null;
      if (details.href !== "WebsiteAssets/documentpunten.jpg") {
        const fallback = {
          ...details,
          href: "WebsiteAssets/documentpunten.jpg",
          alt: "Echte schermafbeelding van CommissieWijzer met documentpunten naast het fictieve raadsvoorstel.",
          caption: "Echte appweergave · documentpunten naast het fictieve raadsvoorstel.",
          width: 2560,
          height: 1680
        };
        selectFeatureImageFallback(fallback);
      }
    };
    incoming.src = details.href;
    incoming.width = details.width || 2560;
    incoming.height = details.height || 1680;
    if (focus) tab.focus();
  }

  function selectFeatureImageFallback(details) {
    const token = ++featureRequest;
    const incomingIndex = 1 - activeFeatureImage;
    const incoming = featureImages[incomingIndex];
    const active = featureImages[activeFeatureImage];
    incoming.onerror = null;
    incoming.onload = () => {
      if (token !== featureRequest) return;
      incoming.alt = details.alt;
      incoming.removeAttribute("aria-hidden");
      active.setAttribute("aria-hidden", "true");
      if (motionPreference.matches) {
        incoming.classList.add("is-active");
        active.classList.remove("is-active");
        activeFeatureImage = incomingIndex;
      } else {
        window.requestAnimationFrame(() => {
          if (token !== featureRequest) return;
          incoming.classList.add("is-active");
          active.classList.remove("is-active");
          activeFeatureImage = incomingIndex;
          featureFadeTimer = window.setTimeout(() => {
            if (token === featureRequest) active.classList.remove("is-active");
          }, 1200);
        });
      }
      featureLink.href = "WebsiteAssets/documentpunten.jpg";
      updateFeatureText(featureTabs.find(candidate => candidate.getAttribute("aria-selected") === "true"), details);
    };
    incoming.onerror = () => { incoming.onerror = null; };
    incoming.src = "WebsiteAssets/documentpunten.jpg";
    incoming.width = 2560;
    incoming.height = 1680;
  }

  featureTabs.forEach((tab, index) => {
    tab.addEventListener("click", () => selectFeature(tab));
    tab.addEventListener("keydown", event => {
      let next;
      if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (index + 1) % featureTabs.length;
      else if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (index - 1 + featureTabs.length) % featureTabs.length;
      else if (event.key === "Home") next = 0;
      else if (event.key === "End") next = featureTabs.length - 1;
      else return;
      event.preventDefault();
      selectFeature(featureTabs[next], true);
    });
  });

  // Optional one-screen navigation. It activates only on pages that mark their
  // direct main sections with data-screen; ordinary pages keep native scrolling.
  const screens = [...document.querySelectorAll("main > section[data-screen]")];
  if (screens.length > 1) {
    const introOptions = document.querySelector(".intro-options");
    const compactWidth = window.matchMedia("(max-width: 700px)");
    function setIntroLayout() {
      introOptions.open = !compactWidth.matches;
    }
    setIntroLayout();
    compactWidth.addEventListener("change", setIntroLayout);

    let transitionUntil = 0;
    let wheelQuietTimer = 0;
    let wheelLocked = false;
    let touch = null;
    function nearestScreenIndex() {
      let nearest = 0;
      for (let i = 1; i < screens.length; i++) {
        if (Math.abs(screens[i].getBoundingClientRect().top) <
            Math.abs(screens[nearest].getBoundingClientRect().top)) nearest = i;
      }
      return nearest;
    }
    function canScrollInside(target, direction) {
      const owner = screens[nearestScreenIndex()];
      for (let node = target instanceof Element ? target : null; node && node !== owner; node = node.parentElement) {
        const style = getComputedStyle(node);
        if (!/(auto|scroll|overlay)/.test(style.overflowY)) continue;
        if (direction > 0 && node.scrollTop + node.clientHeight < node.scrollHeight - 2) return true;
        if (direction < 0 && node.scrollTop > 2) return true;
      }
      return false;
    }
    function navigate(index) {
      index = Math.max(0, Math.min(screens.length - 1, index));
      if (index === nearestScreenIndex()) return false;
      transitionUntil = performance.now() + 760;
      const screen = screens[index];
      screen.scrollIntoView({ behavior: motionPreference.matches ? "instant" : "smooth", block: "start" });
      screen.focus({ preventScroll: true });
      return true;
    }
    function move(direction) {
      const current = nearestScreenIndex();
      const next = current + direction;
      if (next < 0 || next >= screens.length) return false;
      return navigate(next);
    }
    function armWheelUnlock() {
      clearTimeout(wheelQuietTimer);
      const delay = Math.max(220, transitionUntil - performance.now());
      wheelQuietTimer = setTimeout(() => { wheelLocked = false; transitionUntil = 0; }, delay);
    }
    document.addEventListener("wheel", event => {
      const direction = Math.sign(event.deltaY);
      if (!direction || event.ctrlKey || Math.abs(event.deltaX) > Math.abs(event.deltaY)) return;
      if (wheelLocked) armWheelUnlock();
      if (wheelLocked) { event.preventDefault(); return; }
      if (canScrollInside(event.target, direction)) return;
      if (move(direction)) {
        event.preventDefault();
        wheelLocked = true;
        armWheelUnlock();
      }
    }, { passive: false });

    document.addEventListener("touchstart", event => {
      if (event.touches.length !== 1) { touch = null; return; }
      touch = { y: event.touches[0].clientY, x: event.touches[0].clientX, target: event.target, owner: null, moved: false };
    }, { passive: true });
    document.addEventListener("touchmove", event => {
      if (!touch || event.touches.length !== 1) { touch = null; return; }
      const dx = touch.x - event.touches[0].clientX;
      const dy = touch.y - event.touches[0].clientY;
      if (touch.owner === null && (Math.abs(dx) > 10 || Math.abs(dy) > 10)) {
        if (Math.abs(dx) > Math.abs(dy) * 1.2) touch.owner = "native";
        else {
          const direction = Math.sign(dy);
          touch.owner = canScrollInside(touch.target, direction) ? "native" : "screen";
        }
      }
      if (touch.owner !== "screen") return;
      event.preventDefault();
      if (!touch.moved && Math.abs(dy) > 55) {
        touch.moved = move(Math.sign(dy));
      }
    }, { passive: false });
    document.addEventListener("touchend", () => { touch = null; }, { passive: true });
    document.addEventListener("touchcancel", () => { touch = null; }, { passive: true });

    document.addEventListener("keydown", event => {
      const el = event.target;
      if (el.closest("input, textarea, select, [contenteditable='true'], button, a, [role='tab']") || event.altKey || event.ctrlKey || event.metaKey || event.repeat) return;
      let direction = 0;
      if (event.key === "ArrowDown" || event.key === "PageDown" || (event.key === " " && !event.shiftKey)) direction = 1;
      else if (event.key === "ArrowUp" || event.key === "PageUp" || (event.key === " " && event.shiftKey)) direction = -1;
      else if (event.key === "Home") direction = -screens.length;
      else if (event.key === "End") direction = screens.length;
      if (!direction) return;
      if (Math.abs(direction) === 1 && canScrollInside(event.target, direction)) return;
      const changed = Math.abs(direction) > 1
        ? navigate(direction < 0 ? 0 : screens.length - 1)
        : move(direction);
      if (changed) event.preventDefault();
    });
  }

  root.classList.add("js");
  const revealItems = [...document.querySelectorAll(".reveal")];
  if ("IntersectionObserver" in window && !motionPreference.matches) {
    const revealObserver = new IntersectionObserver(entries => entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    }), { threshold: .08, rootMargin: "0px 0px -24px 0px" });
    revealItems.forEach(item => revealObserver.observe(item));
  } else {
    revealItems.forEach(item => item.classList.add("is-visible"));
  }
})();
