// ─────────────────────────────────────────────────────────────
// Cloud Resume v3 — script.js
// ─────────────────────────────────────────────────────────────

const API_ENDPOINT = 'VISITOR_COUNTER_API_URL';

// ── 1. Scroll Reveal ─────────────────────────────────────────
// Root: null (viewport) — this is a standard-scroll page, not a pane
const scrollReveal = {
  init() {
    const targets = document.querySelectorAll('.reveal');
    if (!targets.length) return;

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add('is-visible');
            observer.unobserve(entry.target);
          }
        });
      },
      {
        root: null,
        threshold: 0.12,
        rootMargin: '0px 0px -40px 0px',
      }
    );

    targets.forEach((el) => observer.observe(el));
  },
};

// ── 2. Nav Scroll Behaviour ───────────────────────────────────
const navScroll = {
  navbar: null,
  links: [],
  sections: [],
  rafId: null,

  init() {
    this.navbar = document.getElementById('navbar');
    if (!this.navbar) return;

    this.links = Array.from(document.querySelectorAll('.navbar__link[href^="#"]'));

    // Collect all sections that have a matching nav link
    this.sections = this.links
      .map((l) => document.querySelector(l.getAttribute('href')))
      .filter(Boolean);

    // Smooth scroll + prevent jump
    this.links.forEach((link) => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const target = document.querySelector(link.getAttribute('href'));
        if (target) target.scrollIntoView({ behavior: 'smooth', block: 'start' });
        // Close mobile drawer if open
        mobileMenu.close();
      });
    });

    // Scroll-based updates (throttled via rAF)
    window.addEventListener('scroll', () => {
      if (this.rafId) return;
      this.rafId = requestAnimationFrame(() => {
        this.rafId = null;
        this.onScroll();
      });
    }, { passive: true });

    // Run once on load
    this.onScroll();
  },

  onScroll() {
    const scrollY = window.scrollY;

    // Scrolled class for navbar background
    if (scrollY > 60) {
      this.navbar.classList.add('scrolled');
    } else {
      this.navbar.classList.remove('scrolled');
    }

    // Active nav link
    let activeHref = null;
    const threshold = 80;

    for (const section of this.sections) {
      const top = section.getBoundingClientRect().top + scrollY;
      if (top - threshold <= scrollY) {
        activeHref = '#' + section.id;
      } else {
        break;
      }
    }

    this.links.forEach((link) => {
      link.classList.toggle('active', link.getAttribute('href') === activeHref);
    });
  },
};

// ── 3. Mobile Menu ────────────────────────────────────────────
const mobileMenu = {
  btn: null,
  drawer: null,
  open: false,

  init() {
    this.btn    = document.querySelector('.navbar__hamburger');
    this.drawer = document.querySelector('.navbar__drawer');
    if (!this.btn || !this.drawer) return;

    this.btn.addEventListener('click', () => {
      this.open ? this.close() : this.openMenu();
    });
  },

  openMenu() {
    this.open = true;
    this.drawer.classList.add('is-open');
    this.drawer.setAttribute('aria-hidden', 'false');
    this.btn.setAttribute('aria-expanded', 'true');
    // Animate hamburger to X
    const spans = this.btn.querySelectorAll('span');
    spans[0].style.transform = 'translateY(7px) rotate(45deg)';
    spans[1].style.opacity   = '0';
    spans[2].style.transform = 'translateY(-7px) rotate(-45deg)';
  },

  close() {
    this.open = false;
    this.drawer.classList.remove('is-open');
    this.drawer.setAttribute('aria-hidden', 'true');
    this.btn.setAttribute('aria-expanded', 'false');
    const spans = this.btn.querySelectorAll('span');
    spans[0].style.transform = '';
    spans[1].style.opacity   = '';
    spans[2].style.transform = '';
  },
};

// ── 4. Marquee — clone content until track fills any screen ──
// The CSS animation uses translateX(-50%), which requires the total
// track width to be at least 2× the viewport. We clone the existing
// content until that threshold is met so large/4K screens never see
// the loop point.
const marquee = {
  init() {
    const track = document.querySelector('.cert-strip__track');
    if (!track) return;
    const snap = track.innerHTML;
    requestAnimationFrame(() => {
      // Clone until track comfortably exceeds 2.5× viewport
      const needed = window.innerWidth * 2.5;
      while (track.scrollWidth < needed) {
        track.insertAdjacentHTML('beforeend', snap);
      }

      // Set duration so scroll speed is always ~55px/s regardless of track length
      // The animation moves -50% of total track width
      const distance = track.scrollWidth * 0.5;
      const duration = distance / 30; // seconds
      track.style.animationDuration = `${duration.toFixed(1)}s`;
    });
  },
};

// ── 5. Visitor Counter ────────────────────────────────────────
async function updateVisitorCount() {
  const el = document.getElementById('visitor-count');
  if (!el) return;
  try {
    const response = await fetch(API_ENDPOINT, { method: 'POST' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    el.textContent = data.count;
  } catch {
    el.textContent = '\u2014';
  }
}

// ── 5. Photo: hide placeholder once headshot.png loads ───────
function initPhotoFallback() {
  const photo       = document.querySelector('.hero__photo');
  const placeholder = document.querySelector('.hero__photo-placeholder');
  if (!photo || !placeholder) return;

  const hide = () => { placeholder.style.display = 'none'; };

  if (photo.complete && photo.naturalWidth > 0) {
    hide();
  } else {
    photo.addEventListener('load', hide);
    // If src is missing / broken, placeholder stays visible
  }
}

// ── Init ──────────────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  scrollReveal.init();
  navScroll.init();
  mobileMenu.init();
  marquee.init();
  initPhotoFallback();
  updateVisitorCount();
});
