// Cybernie landing page. Plain JavaScript, no libraries.
(() => {
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const $ = (sel, root = document) => root.querySelector(sel);
  const rand = (a, b) => a + Math.random() * (b - a);

  // The game's characters, with each sprite strip's frame size (see img/).
  const heroes = [
    { id: 'luna', name: 'Luna', w: 101, frames: 8, line: 'Moon-touched and a little sleepy.' },
    { id: 'rogue', name: 'Rogue', w: 90, frames: 8, line: 'Cap on, hood up, always nearby.' },
    { id: 'mage', name: 'Mage', w: 128, frames: 8, line: 'Knows a spell for every drink.' },
    { id: 'lily', name: 'Lily', w: 101, frames: 8, line: 'Quiet, until the cards come out.' },
    { id: 'thief', name: 'Thief', w: 101, frames: 8, line: 'Swears that coin was already his.' },
    { id: 'slime', name: 'Slime', w: 120, frames: 16, line: 'Squishes when it walks. Proudly.' },
  ];
  const emotes = ['wave', 'cheers', 'love', 'thumbs', 'surprised', 'dizzy', 'angry', 'crying'];

  const sprite = (sheet, w, frames, extra = '') =>
    `<div class="sprite-anim" style="--sheet:url(img/${sheet}.png);--frames:${frames};--ar:${w}/128;${extra}"></div>`;

  // ---------- Top bar turns solid once you scroll ----------
  const bar = $('#bar');
  const onScrollBar = () => bar.classList.toggle('is-solid', scrollY > 30);
  addEventListener('scroll', onScrollBar, { passive: true });
  onScrollBar();

  // ---------- Stars ----------
  const stars = $('#stars');
  for (let i = 0; i < 90; i++) {
    const s = document.createElement('i');
    s.style.left = `${rand(0, 100)}%`;
    s.style.top = `${rand(0, 70)}%`;
    s.style.setProperty('--t', `${rand(2, 5)}s`);
    s.style.setProperty('--d', `${rand(0, 4)}s`);
    if (Math.random() < .15) { s.style.width = s.style.height = '3px'; }
    stars.appendChild(s);
  }

  // ---------- The street: heroes walking past, popping emotes ----------
  const walkers = $('#walkers');
  if (!reduceMotion) {
    const lanes = heroes.map((h, i) => {
      const el = document.createElement('div');
      el.className = 'walker';
      el.innerHTML = `<img class="walker__emote" alt="">` +
        sprite(`${h.id}_east`, h.w, h.frames, `--speed:${h.frames === 16 ? 1 : .72}s`);
      walkers.appendChild(el);
      // Each walks at its own pace, spread out along the street.
      return { el, speed: rand(55, 80), x: (i / heroes.length) * (innerWidth + 240) - 120 };
    });
    let last = performance.now();
    const step = (now) => {
      const dt = Math.min(.05, (now - last) / 1000);
      last = now;
      const span = innerWidth + 240;
      for (const l of lanes) {
        l.x += l.speed * dt;
        if (l.x > innerWidth + 120) l.x -= span;
        l.el.style.transform = `translateX(${l.x}px)`;
      }
      requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
    setInterval(() => {
      const l = lanes[Math.floor(Math.random() * lanes.length)];
      const img = l.el.querySelector('.walker__emote');
      img.src = `img/emote_${emotes[Math.floor(Math.random() * emotes.length)]}.png`;
      img.classList.remove('is-on');
      void img.offsetWidth;
      img.classList.add('is-on');
    }, 1400);
  }

  // ---------- The tour: fly around the map as you scroll ----------
  const tour = $('#tour');
  const win = $('.tour__window');
  const map = $('#map');
  const mapUp = $('#mapUp');
  const steps = [...document.querySelectorAll('.step')];
  const dots = [...document.querySelectorAll('#dots i')];
  const pings = [...map.querySelectorAll('.ping')];

  // Place the live bits (fire, bard, pings, projector) in map pixels.
  for (const el of document.querySelectorAll('[data-x]')) {
    const x = +el.dataset.x, y = +el.dataset.y;
    const w = +(el.dataset.w || 0), h = +(el.dataset.h || 0);
    if (w) { el.style.width = `${w}px`; el.style.height = `${h}px`; }
    if (el.dataset.anchor === 'feet') {
      // Feet at (x, y), as in the game (about 97% down the frame).
      el.style.left = `${x - w / 2}px`; el.style.top = `${y - h * .97}px`;
    } else {
      el.style.left = `${x}px`; el.style.top = `${y}px`;
    }
  }

  // Each stop: where to look (map pixels), how close, which map.
  const stops = [
    { x: 701, y: 575, zoom: 1.1, up: 0 },     // the whole tavern
    { x: 610, y: 330, zoom: 1.9, up: 0 },     // the bar and Bernie
    { x: 250, y: 620, zoom: 1.7, up: 0 },     // fireplace corner, tables
    { x: 1170, y: 270, zoom: 1.8, up: 0 },    // notice board and stairs
    { x: 744, y: 290, zoom: 1.6, up: 1 },     // upstairs, the projector
  ];

  const fitZoom = (w, h) => Math.max(win.clientWidth / w, win.clientHeight / h);
  const view = (stop) => {
    const up = stop.up;
    const mw = up ? 1448 : 1402, mh = up ? 1086 : 1122;
    const z = stop.zoom === 'fit' ? fitZoom(mw, mh) : stop.zoom * fitZoom(mw, mh);
    return { x: stop.x, y: stop.y, z };
  };
  const ease = (t) => t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;

  const place = (el, x, y, z, mw, mh) => {
    // Keep the point (x, y) centred, without showing past the map edge.
    const vw = win.clientWidth, vh = win.clientHeight;
    let tx = vw / 2 - x * z, ty = vh / 2 - y * z;
    tx = Math.min(0, Math.max(vw - mw * z, tx));
    ty = Math.min(0, Math.max(vh - mh * z, ty));
    el.style.transform = `translate(${tx}px, ${ty}px) scale(${z})`;
  };

  let current = -1;
  const updateTour = () => {
    const r = tour.getBoundingClientRect();
    const total = tour.offsetHeight - innerHeight;
    const p = Math.min(1, Math.max(0, -r.top / total)) * (stops.length - 1);
    const i = Math.min(stops.length - 2, Math.floor(p));
    const t = reduceMotion ? Math.round(p - i) : ease(p - i);
    const a = view(stops[i]), b = view(stops[i + 1]);
    const goingUp = !stops[i].up && stops[i + 1].up;

    if (goingUp) {
      // Zoom into the stairs, fade to upstairs.
      const z = a.z * (1 + t * .8);
      place(map, 1131 * t + a.x * (1 - t), 250 * t + a.y * (1 - t), z, 1402, 1122);
      place(mapUp, b.x, b.y, b.z * (1.15 - .15 * t), 1448, 1086);
      mapUp.style.opacity = Math.max(0, (t - .35) / .65);
      map.style.opacity = 1;
    } else if (stops[i].up) {
      place(mapUp, b.x, b.y, b.z, 1448, 1086);
      mapUp.style.opacity = 1;
    } else {
      place(map, a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t, 1402, 1122);
      mapUp.style.opacity = 0;
    }

    const now = Math.round(p);
    if (now !== current) {
      current = now;
      steps.forEach((s, k) => s.classList.toggle('is-on', k === now));
      dots.forEach((d, k) => d.classList.toggle('is-on', k === now));
      pings.forEach((pg, k) => pg.classList.toggle('is-on', k === now - 1));
    }
  };
  let ticking = false;
  const requestTour = () => {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => { ticking = false; updateTour(); });
  };
  addEventListener('scroll', requestTour, { passive: true });
  addEventListener('resize', requestTour);
  updateTour();

  // ---------- Roster cards ----------
  const cards = $('#cards');
  for (const h of heroes) {
    const card = document.createElement('button');
    card.type = 'button';
    card.className = 'card reveal';
    card.setAttribute('aria-label', `${h.name}: ${h.line}`);
    card.innerHTML =
      `<div class="card__stage">${sprite(`${h.id}_idle`, h.w, h.frames, '--speed:1.4s')}</div>` +
      `<span class="card__name">${h.name}</span>` +
      `<p class="card__line">${h.line}</p>`;
    const anim = card.querySelector('.sprite-anim');
    const walk = (on) => {
      card.classList.toggle('is-walking', on);
      anim.style.setProperty('--sheet', `url(img/${h.id}_${on ? 'east' : 'idle'}.png)`);
    };
    card.addEventListener('mouseenter', () => walk(true));
    card.addEventListener('mouseleave', () => walk(false));
    card.addEventListener('click', () => walk(!card.classList.contains('is-walking')));
    cards.appendChild(card);
  }

  // ---------- Proximity voice demo (the game's own volume curve) ----------
  const distance = $('#distance');
  const friend = $('#friend');
  const meter = $('#meter');
  const readout = $('#volumeText');
  const rings = $('#rings');
  const cam = $('#camBubble');
  const NEAR = 110, FAR = 420, CONNECT = 450;
  const updateVoice = () => {
    const d = +distance.value;
    const t = Math.min(1, Math.max(0, (d - NEAR) / (FAR - NEAR)));
    const volume = d > CONNECT ? 0 : Math.pow(1 - t, 2);
    // 60..560 map pixels across the floor.
    friend.style.left = `${24 + (d - 60) / 500 * 62}%`;
    meter.style.width = `${Math.round(volume * 100)}%`;
    rings.style.setProperty('--reach', (2 + volume * 8).toFixed(1));
    rings.style.opacity = volume > 0 ? 1 : .15;
    cam.style.opacity = d > CONNECT ? 0 : 1;
    readout.textContent =
      d <= NEAR ? 'Right next to you: full volume.'
      : d > CONNECT ? 'Out of earshot: the call hangs up until you walk back.'
      : `${Math.round(volume * 100)}% volume, ${Math.round(d)} steps away.`;
  };
  distance.addEventListener('input', updateVoice);
  updateVoice();

  // ---------- Lucky wheel (the game's slices, clockwise from the top) ----------
  const slices = [50, 200, 80, 500, 100, 150, 1000];
  const chances = [34, 4, 27, 2, 21, 11, 1];
  const disc = $('#wheelDisc');
  const spin = $('#spin');
  const result = $('#wheelResult');
  let turns = 0;
  spin.addEventListener('click', () => {
    let roll = Math.random() * 100, index = 0;
    while (roll >= chances[index]) { roll -= chances[index]; index++; }
    const slice = 360 / slices.length;
    turns += 6;
    const target = turns * 360 + index * slice + rand(-.35, .35) * slice;
    spin.disabled = true;
    result.textContent = 'Spinning…';
    disc.style.transform = `rotate(${-target}deg)`;
    setTimeout(() => {
      result.textContent = `You won ${slices[index]} coins!`;
      spin.disabled = false;
    }, reduceMotion ? 50 : 4700);
  });

  // ---------- Blackjack with Bernie (his poses as in the game) ----------
  // bj_bernie.png is 5 x 5 poses: 0 idle, 1 smile, 2 sly, 3 laugh, 4 sulk,
  // 5 surprised, 6 shocked, 7 wink, 8 pleased, 9-16 shuffle, 17-24 thinking.
  const bernie = $('#bjBernie');
  const say = $('#bjSay');
  const dealerBox = $('#bjDealer');
  const youBox = $('#bjYou');
  const dealBtn = $('#bjDeal'), hitBtn = $('#bjHit'), standBtn = $('#bjStand');
  const dealerTotal = $('#bjDealerTotal'), youTotal = $('#bjYouTotal');
  let loop = null;
  const pose = (cell) => {
    bernie.style.backgroundPosition = `${(cell % 5) * 25}% ${Math.floor(cell / 5) * 25}%`;
  };
  const play = (first, frames, ms, repeat, then) => {
    clearInterval(loop);
    let i = 0;
    pose(first);
    loop = setInterval(() => {
      i++;
      if (!repeat && i >= frames) { clearInterval(loop); then && then(); return; }
      pose(first + (i % frames));
    }, reduceMotion ? 1 : ms);
  };
  const talk = (text) => {
    say.textContent = text;
    say.classList.remove('is-new');
    void say.offsetWidth;
    say.classList.add('is-new');
  };
  const pick = (list) => list[Math.floor(Math.random() * list.length)];

  // The deck: columns A, 2-10, J, Q, K; rows hearts, diamonds, clubs, spades.
  let deck = [], you = [], dealer = [];
  const shuffle = () => {
    deck = [];
    for (let s = 0; s < 4; s++) for (let r = 0; r < 13; r++) deck.push({ r, s });
    for (let i = deck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [deck[i], deck[j]] = [deck[j], deck[i]];
    }
  };
  const value = (hand) => {
    let total = 0, aces = 0;
    for (const c of hand) {
      if (c.r === 0) { aces++; total += 11; } else total += Math.min(10, c.r + 1);
    }
    while (total > 21 && aces) { total -= 10; aces--; }
    return total;
  };
  const face = (el, c) => {
    el.classList.remove('is-back');
    el.style.backgroundPosition = `${c.r / 12 * 100}% ${c.s / 3 * 100}%`;
    el.setAttribute('aria-label', `${['Ace', 2, 3, 4, 5, 6, 7, 8, 9, 10, 'Jack', 'Queen', 'King'][c.r]} of ${['hearts', 'diamonds', 'clubs', 'spades'][c.s]}`);
  };
  const deal = (box, hand, hidden = false) => {
    const c = deck.pop();
    hand.push(c);
    const el = document.createElement('div');
    el.className = 'card-c is-flying';
    el.setAttribute('role', 'img');
    if (hidden) { el.classList.add('is-back'); el.setAttribute('aria-label', 'Face-down card'); } else face(el, c);
    // Flies in from Bernie's paws.
    el.style.setProperty('--fx', box === youBox ? '-120%' : '60%');
    el.style.setProperty('--fy', box === youBox ? '-160%' : '-90%');
    box.appendChild(el);
    requestAnimationFrame(() => requestAnimationFrame(() => el.classList.remove('is-flying')));
    return el;
  };
  const showTotals = (reveal) => {
    youTotal.textContent = `You: ${value(you)}`;
    dealerTotal.textContent = reveal ? `Bernie: ${value(dealer)}` : `Bernie: ${value(dealer.slice(0, 1))} + ?`;
  };
  const buttons = (playing) => {
    dealBtn.disabled = playing;
    hitBtn.disabled = standBtn.disabled = !playing;
  };
  const finish = (text, cell) => {
    clearInterval(loop);
    pose(cell);
    talk(text);
    buttons(false);
    dealBtn.textContent = 'Deal again';
  };
  let hole = null;

  dealBtn.addEventListener('click', () => {
    buttons(true);
    hitBtn.disabled = standBtn.disabled = true;
    dealerBox.innerHTML = youBox.innerHTML = '';
    you = []; dealer = [];
    shuffle();
    talk(pick(['Let me shuffle these…', 'Cards are fresh, friend.', 'Watch my paws.']));
    play(9, 8, 120, false, () => {
      setTimeout(() => deal(youBox, you), 0);
      setTimeout(() => deal(dealerBox, dealer), 250);
      setTimeout(() => deal(youBox, you), 500);
      setTimeout(() => {
        hole = deal(dealerBox, dealer, true);
        showTotals(false);
        if (value(you) === 21) return stand();
        hitBtn.disabled = standBtn.disabled = false;
        talk(pick(['Hit or stand?', 'Your move.', 'Feeling lucky?']));
        play(17, 8, 200, true);
      }, 750);
    });
  });
  hitBtn.addEventListener('click', () => {
    deal(youBox, you);
    showTotals(false);
    if (value(you) > 21) {
      setTimeout(() => finish(pick(['Bust! Better luck next time.', 'Ooh, too many.']), pick([3, 7, 1])), 450);
    } else if (value(you) === 21) {
      stand();
    }
  });
  const stand = () => {
    hitBtn.disabled = standBtn.disabled = true;
    clearInterval(loop);
    pose(2);
    talk('My turn…');
    // Turn the face-down card over, then draw to 17.
    setTimeout(() => {
      hole.classList.add('is-flip');
      setTimeout(() => face(hole, dealer[1]), 220);
      showTotals(true);
      const draw = () => {
        if (value(dealer) < 17) {
          deal(dealerBox, dealer);
          showTotals(true);
          setTimeout(draw, 550);
          return;
        }
        const d = value(dealer), y = value(you);
        if (d > 21) finish('I… went over. You win!', pick([6, 4, 5]));
        else if (y > d) finish(pick(['You win this one.', 'Hmph. Well played.']), pick([4, 5, 6]));
        else if (y < d) finish(pick(['The house wins!', 'Mine, I think.']), pick([8, 3, 7]));
        else finish('A push. Nobody wins.', 7);
      };
      setTimeout(draw, 600);
    }, 500);
  };
  standBtn.addEventListener('click', stand);
  pose(0);

  // ---------- Drinks ----------
  const effect = $('#drinkEffect');
  for (const btn of document.querySelectorAll('.drinks button')) {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.drinks button').forEach((b) => b.classList.remove('is-on'));
      void btn.offsetWidth;
      btn.classList.add('is-on');
      effect.textContent = btn.dataset.effect;
    });
  }

  // ---------- Emotes ----------
  const emoteBox = $('#emotes');
  const stage = $('#emoteStage');
  for (const e of emotes) {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('aria-label', `Emote: ${e}`);
    b.innerHTML = `<img src="img/emote_${e}.png" alt="">`;
    b.addEventListener('click', () => {
      const pop = document.createElement('img');
      pop.className = 'emote-pop';
      pop.src = `img/emote_${e}.png`;
      pop.alt = '';
      stage.appendChild(pop);
      setTimeout(() => pop.remove(), 2100);
    });
    emoteBox.appendChild(b);
  }

  // ---------- The bard's music notes ----------
  const notes = $('#notes');
  if (!reduceMotion) {
    setInterval(() => {
      if (notes.getBoundingClientRect().top > innerHeight) return;
      const n = document.createElement('span');
      n.className = 'note';
      n.textContent = ['♪', '♫', '♩'][Math.floor(Math.random() * 3)];
      n.style.setProperty('--dx', `${rand(-60, 60)}px`);
      n.style.setProperty('--rot', `${rand(-30, 30)}deg`);
      notes.appendChild(n);
      setTimeout(() => n.remove(), 3000);
    }, 600);
  }

  // ---------- Friends: little looping demos ----------
  // Add friends: type a name, press Add, it turns into "Requested".
  const typed = $('#typed');
  const addBtn = $('#addBtn');
  const typeLoop = () => {
    const word = 'Luna';
    let i = 0;
    typed.textContent = '';
    addBtn.textContent = 'Add';
    addBtn.classList.remove('is-sent');
    const t = setInterval(() => {
      typed.textContent = word.slice(0, ++i);
      if (i < word.length) return;
      clearInterval(t);
      setTimeout(() => addBtn.classList.add('is-press'), 700);
      setTimeout(() => {
        addBtn.classList.remove('is-press');
        addBtn.classList.add('is-sent');
        addBtn.textContent = 'Requested ✓';
      }, 900);
      setTimeout(typeLoop, 3600);
    }, 180);
  };

  // Messages: a short conversation, then a new message banner slides in.
  const chat = $('#chat');
  const dmBanner = $('#dmBanner');
  const lines = [
    ['them', 'you coming tonight?'],
    ['me', 'yeah! saving you a seat by the fire'],
    ['them', '<img src="img/emote_love.png" alt="love emote">'],
  ];
  const chatLoop = () => {
    chat.innerHTML = '';
    dmBanner.classList.remove('is-on');
    lines.forEach(([who, text], k) => setTimeout(() => {
      const m = document.createElement('div');
      m.className = `msg msg--${who}`;
      m.innerHTML = text;
      chat.appendChild(m);
    }, 600 + k * 1100));
    setTimeout(() => dmBanner.classList.add('is-on'), 4400);
    setTimeout(() => dmBanner.classList.remove('is-on'), 7000);
    setTimeout(chatLoop, 8000);
  };

  // QR: a real code for this site's game, so scanning it opens Cybernie.
  const qrBox = $('#qrCode');
  const gameUrl = new URL('../', location.href).href;
  if (window.QRCode) {
    new QRCode(qrBox, { text: gameUrl, width: 256, height: 256, colorDark: '#2a1408', colorLight: '#ffffff', correctLevel: QRCode.CorrectLevel.M });
  }
  qrBox.setAttribute('aria-label', `QR code that opens ${gameUrl}`);

  // Start the demos once the section is on screen.
  if (reduceMotion) {
    typed.textContent = 'Luna';
    lines.forEach(([who, text]) => chat.insertAdjacentHTML('beforeend', `<div class="msg msg--${who}">${text}</div>`));
  } else {
    let started = false;
    new IntersectionObserver((entries, obs) => {
      if (started || !entries.some((e) => e.isIntersecting)) return;
      started = true;
      obs.disconnect();
      typeLoop();
      chatLoop();
    }).observe($('#friends'));
  }

  // ---------- Background music (the game's own song) ----------
  // It plays by itself: right away where the browser allows it, otherwise on
  // the visitor's first click, tap or key press anywhere (browsers block
  // sound until then). Turning it off with the button is remembered.
  const bgm = $('#bgm');
  const musicBtn = $('#music');
  const MUSIC_KEY = 'cybernie-landing-music';
  const VOLUME = .35;
  let fade = null;
  let playing = false;
  const showButton = (on) => {
    musicBtn.setAttribute('aria-pressed', String(on));
    musicBtn.setAttribute('aria-label', on ? 'Pause the tavern music' : 'Play the tavern music');
  };
  const remember = (on) => {
    try { localStorage.setItem(MUSIC_KEY, on ? '1' : '0'); } catch (_) { /* private mode */ }
  };
  // Starts the music (fading in). Resolves false if the browser blocked it.
  const start = () => {
    if (playing) return Promise.resolve(true);
    clearInterval(fade);
    bgm.volume = 0;
    return bgm.play().then(() => {
      playing = true;
      showButton(true);
      fade = setInterval(() => {
        bgm.volume = Math.min(VOLUME, bgm.volume + .02);
        if (bgm.volume >= VOLUME) clearInterval(fade);
      }, 60);
      return true;
    }).catch(() => false);
  };
  const stop = () => {
    playing = false;
    showButton(false);
    clearInterval(fade);
    fade = setInterval(() => {
      bgm.volume = Math.max(0, bgm.volume - .03);
      if (bgm.volume <= 0) { clearInterval(fade); bgm.pause(); }
    }, 40);
  };
  musicBtn.addEventListener('click', () => {
    if (playing) { stop(); remember(false); } else { start(); remember(true); }
  });

  // On unless the visitor switched it off before.
  let musicOff = false;
  try { musicOff = localStorage.getItem(MUSIC_KEY) === '0'; } catch (_) { /* private mode */ }
  if (!musicOff) {
    bgm.preload = 'auto';
    start().then((ok) => {
      if (ok) return;
      // Blocked: start on the first interaction instead.
      const events = ['pointerdown', 'keydown', 'touchstart'];
      const kick = (e) => {
        events.forEach((t) => removeEventListener(t, kick, true));
        // A click on the music button itself is handled by the button.
        if (e.target.closest && e.target.closest('#music')) return;
        start();
      };
      events.forEach((t) => addEventListener(t, kick, true));
    });
  }

  // ---------- Fade sections in as they arrive ----------
  for (const el of document.querySelectorAll('.h2, .sub, .eyebrow, .tile, .demo, .ticks, .close__title')) {
    el.classList.add('reveal');
  }
  const io = new IntersectionObserver((entries) => {
    entries.forEach((e, k) => {
      if (!e.isIntersecting) return;
      setTimeout(() => e.target.classList.add('is-in'), k * 70);
      io.unobserve(e.target);
    });
  }, { rootMargin: '0px 0px -10% 0px' });
  document.querySelectorAll('.reveal').forEach((el) => io.observe(el));
})();
