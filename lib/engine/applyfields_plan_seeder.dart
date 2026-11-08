import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_models.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';

/// One-time import of the ApplyFields plan:
///  * a note "ApplyFields" with the 4 versions as a tickable checklist
///  * the Week 1 tasks (Mon 5 – Fri 9 Oct 2026) for Likhith, Karthik and Harsha as calendar events
///
/// Only INSERTS rows with its own ids (prefix `af_`) — existing notes and events are never touched.
/// Runs once: a SharedPreferences flag stops it from re-adding anything you later edit or delete.
class ApplyFieldsPlanSeeder {
  static const _flag = 'applyfields_plan_seeded_v1';
  static const noteId = 'af_note_plan';

  /// Category for Karthik's and Harsha's tasks — the calendar skips them in conflict checks.
  static const teamCategory = 'Team';
  static const ownCategory = 'ApplyFields';

  static const _colors = {
    'Likhith': '#6366F1', // indigo
    'Karthik': '#10B981', // emerald
    'Harsha': '#F59E0B', // amber
  };

  static Future<void> seedIfNeeded({bool enableVibration = true}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_flag) == true) return;

    final db = DatabaseHelper.instance;
    final existing = await db.getNotes();
    if (existing.any((n) => n.id == noteId)) {
      await prefs.setBool(_flag, true);
      return;
    }

    // ---- Note + checklist -------------------------------------------------
    await db.insertNote(NoteItem(
      id: noteId,
      title: 'ApplyFields',
      category: 'Work',
      body: 'ApplyFields — Every opportunity. One place.\n'
          'Team: Likhith (lead) · Karthik (full stack) · Harsha (Python).\n'
          'Release a version only when its main user journey works end to end.\n'
          'Tick each item below when it is done.',
    ));

    var order = 0;
    for (final phase in _phases) {
      await db.insertChecklistItem(ChecklistItem(
        id: 'af_ck_${order.toString().padLeft(3, '0')}',
        parentId: noteId,
        parentType: 'note',
        text: '## ${phase.title}',
        sortOrder: order++,
      ));
      for (final item in phase.items) {
        await db.insertChecklistItem(ChecklistItem(
          id: 'af_ck_${order.toString().padLeft(3, '0')}',
          parentId: noteId,
          parentType: 'note',
          text: item.text,
          isDone: item.done,
          sortOrder: order++,
        ));
      }
    }

    // ---- Week 1 calendar --------------------------------------------------
    for (final event in _week1Events()) {
      await db.insertEvent(event);
      if (event.reminderMinutesBefore >= 0 && event.completionStatus == 'pending') {
        await NotificationService.instance.scheduleEventReminder(event, enableVibration: enableVibration);
      }
    }

    await prefs.setBool(_flag, true);
  }

  // ------------------------------------------------------------------------
  // The 4 versions (as agreed with the team)

  static final _phases = <_Phase>[
    _Phase('v1 · Foundation — layout + login', [
      _Item('Layout, UI, all pages, design system (web + phone)', done: true),
      _Item('Website ↔ API connection', done: true),
      _Item('Database connected: Supabase + Prisma', done: true),
      _Item('Jobs & exams read from the database (sample data removed)', done: true),
      _Item('Sign up, log in, OTP, sessions, log out'),
      _Item('Profile: personal (gender, category, income), education, state'),
      _Item('Internal Portal staff login and roles'),
      _Item('CI on every PR (lint, typecheck, build, tests)'),
      _Item('Staging deploy (Vercel + Render)'),
    ]),
    _Phase('v2 · Apply Mode', [
      _Item('Scrapers: SSC, UPSC, APPSC, TSPSC, RRB'),
      _Item('Scrapers: NTA, NSP + more portals'),
      _Item('PDF / OCR + AI extraction into the job format'),
      _Item('Review & publish in the Internal Portal'),
      _Item('Jobs, exams, scholarships, admissions — lists + details'),
      _Item('Government services pages'),
      _Item('Results, admit cards and answer keys (updates)'),
      _Item('Eligibility check'),
      _Item('Saved items, reminders, email notifications'),
      _Item('Universal search'),
      _Item('My documents, my applications'),
      _Item('"Report incorrect info"'),
    ]),
    _Phase('v3 · Career Mode', [
      _Item('Career profile and career categories'),
      _Item('Explore careers'),
      _Item('Roadmaps with progress, skills'),
      _Item('Courses, colleges, compare colleges'),
      _Item('AI career guidance'),
      _Item('Links from careers to exams, scholarships and jobs'),
      _Item('Career content management in the Internal Portal'),
    ]),
    _Phase('v4 · Final product', [
      _Item('Partner portal + assistance network (MeeSeva, CSC)'),
      _Item('Payments: ₹50 plan, convenience fees, partner payouts'),
      _Item('Push, SMS and WhatsApp notifications'),
      _Item('Android and iOS apps'),
      _Item('DigiLocker, Google login, Telugu and Hindi'),
      _Item('Analytics, security hardening, performance'),
      _Item('Production launch'),
    ]),
  ];

  // ------------------------------------------------------------------------
  // Week 1 — Mon 5 Oct to Fri 9 Oct 2026 (from the Week 1 plan sheets)

  static const _days = ['2026-10-05', '2026-10-06', '2026-10-07', '2026-10-08', '2026-10-09'];

  static final _tasks = <String, List<List<_Task>>>{
    'Likhith': [
      [
        _Task('Supabase dev database', 'Run 01_create_tables.sql, then 02_team_roles.sql. Check 66 tables, RLS on, guards. Create the 3 logins.', done: true),
        _Task('GitHub', 'Repo in the ApplyFields-in organisation · push the skeleton · protect main · CODEOWNERS @EmptyEch0.', done: true),
        _Task('Kickoff meeting', 'Walk through the plans, rules and design system. Settle the kickoff decisions.', done: true),
        _Task('Share access privately', 'Send each person their password + project reference privately, plus the PDFs and sheets.', done: true),
        _Task('Prisma setup (unblocks Karthik)', 'prisma db pull (66 models) + generate; PrismaService in apps/api.', done: true),
      ],
      [
        _Task('Starter data', 'SQL file in database/changes/: organisations (SSC, UPSC, APPSC, TSPSC, RRB, IBPS, NTA, NSP, AP + TS police) and document types.'),
        _Task('Listings from the database', 'Replace the sample data in opportunities + home with Prisma queries (published rows only).', done: true),
        _Task('Review Karthik\'s PR (register/login)', 'argon2id, hashed refresh tokens, httpOnly cookie, error messages, palette.'),
      ],
      [
        _Task('Design the Internal Portal review screens', '/review list (drafts, confidence, source, found at) and /review/[id]: official PDF left, editable fields right.'),
        _Task('Review Harsha\'s PRs (scrapers)', 'Polite crawling, duplicates skipped, ingestion_writer login, no secrets.'),
      ],
      [
        _Task('Review API', 'GET /admin/review (drafts, newest first) · GET /admin/review/:id (draft + posts + eligibility + dates + signed PDF URL).'),
        _Task('Publish / Reject API', 'POST /admin/opportunities/:id/publish: check required fields, save opportunity_versions snapshot, audit log. Reject with a reason.'),
      ],
      [
        _Task('Staff login & roles', 'Reuse Karthik\'s login + user_roles check (super_admin, admin, reviewer) on every /admin endpoint.'),
        _Task('CI', 'GitHub Actions on every PR: pnpm lint, typecheck, build; ruff + pytest for apps/ingestion.'),
        _Task('Staging deploy', 'Vercel: web + admin · Render: API (+ env vars, dev database). Share the URLs.'),
        _Task('Friday demo + plan Week 2', 'Each person demos; update everyone\'s Week 2 sheet.'),
      ],
    ],
    'Karthik': [
      [
        _Task('Kickoff with the team', 'Rules, the Fields sheet, the design system (packages/ui), how pages are built.'),
        _Task('Set up', 'pnpm install · apps/api/.env with karthik_dev + JWT secrets · apps/web/.env.local. Web, portal and API run locally.'),
        _Task('Look at your tables', 'Connect a SQL tool with karthik_dev. Read users, user_sessions, consents, user_profiles, user_education.'),
        _Task('Register + login pages (UI)', 'Replace the "not built yet" pages in (auth)/login and register. Validate input (not connected yet).'),
      ],
      [
        _Task('Auth API', 'NestJS auth module: register, login, refresh, logout, me. argon2id, hashed refresh tokens. Works in Swagger/Postman.'),
        _Task('Connect pages + logged-in state', 'Pages call the API. Top bar shows name/photo with a menu when logged in. Register → login → log out works.'),
      ],
      [
        _Task('Profile API', 'GET/PUT /me/profile · GET/POST/PUT/DELETE /me/education. Only allowed values.'),
        _Task('Profile page (view)', '/profile: header card with photo, name, state, completeness %; Personal details, Education sections.'),
      ],
      [
        _Task('Edit personal details', 'Every personal field with the right input — date picker, dropdowns for gender, category, state…'),
        _Task('Education: add / edit / delete', 'List of qualifications; add/edit form (level, degree, stream, board, institution, year, marks).'),
      ],
      [
        _Task('Profile picture', 'POST /me/avatar: JPG/PNG ≤ 2 MB to the private "avatars" bucket; replace and remove.'),
        _Task('Profile completeness', '% from filled fields (personal + at least 1 education). Show on /profile and the home card.'),
        _Task('Test, polish, PR + demo', 'Check every page at 390 px. Tests. pnpm lint + typecheck pass. Open PR(s), Friday demo.'),
      ],
    ],
    'Harsha': [
      [
        _Task('Kickoff with the team', 'Job format, rules, guide PDF. Explain the flow: scrape → draft → review → publish → website.'),
        _Task('Set up the Python service', 'cd apps/ingestion · uv sync · .env with ingestion_writer. localhost:8000/health is ok, tests pass.'),
        _Task('Look at your tables', 'With harsha_dev: scrape_sources, scrape_runs, scraped_documents, opportunities.'),
        _Task('Read the contract', 'docs/job-format.md + Guide PDF sections 4–6. Map a notice to the job format JSON.'),
      ],
      [
        _Task('Research 10 portals', 'Fill the "Sources (10)" sheet: notices URL, page type, PDF type, language, robots.txt, CAPTCHA.'),
        _Task('Add the portals to the database', 'One scrape_sources row per portal (key, name, list_url, kind, interval_hours 6).'),
        _Task('Polite fetcher', 'app/fetcher.py with httpx: timeout, 3 retries with backoff, crawl delay, user agent. Tests pass.'),
      ],
      [
        _Task('SSC scraper', 'app/scrapers/ssc.py extends BaseScraper → [title, pdf_url, date] per notice.'),
        _Task('UPSC scraper', 'Same pattern for UPSC.'),
        _Task('Save each notice once', 'Download PDF · SHA-256 · insert scraped_documents. Running twice adds NO duplicates.'),
      ],
      [
        _Task('APPSC, TSPSC, RRB scrapers', 'Three more scrapers with the BaseScraper pattern → 5 portals working.'),
        _Task('Run command + internal endpoint', '"uv run python -m app.run ssc" prints a JSON summary; POST /scrape/{source} works from /docs.'),
      ],
      [
        _Task('Read the PDFs', 'pdfplumber text + Tesseract OCR on 10 downloaded PDFs.'),
        _Task('Findings note', '1 page: which portals work/fail and why, text vs scanned PDFs, Telugu/Hindi issues.'),
        _Task('PR + Friday demo', 'ruff check + pytest pass. Demo: one command scrapes 5 portals → rows in the database.'),
        _Task('Stretch: scheduler', 'Only if everything else is done: APScheduler runs each source every interval_hours.'),
      ],
    ],
  };

  static String _hhmm(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  static List<CalendarEvent> _week1Events() {
    final events = <CalendarEvent>[];

    for (var d = 0; d < _days.length; d++) {
      final date = _days[d];

      events.add(CalendarEvent(
        id: 'af_ev_${date}_standup',
        title: 'ApplyFields standup (15 min)',
        date: date,
        startTime: '10:00',
        endTime: '10:15',
        category: ownCategory,
        priority: 2,
        notes: 'Everyone: what I did yesterday · what I do today · anything blocking me.',
        colorHex: '#8B5CF6',
        completionStatus: date.compareTo('2026-10-06') < 0 ? 'completed' : 'pending',
        reminderMinutesBefore: 15,
      ));

      for (final entry in _tasks.entries) {
        final person = entry.key;
        final dayTasks = entry.value[d];
        // Spread the day's tasks over 10:30–18:30, in 30-minute steps.
        const dayStart = 10 * 60 + 30;
        final slot = ((8 * 60) ~/ dayTasks.length) ~/ 30 * 30;
        for (var i = 0; i < dayTasks.length; i++) {
          final t = dayTasks[i];
          final start = dayStart + i * slot;
          final isOwn = person == 'Likhith';
          events.add(CalendarEvent(
            id: 'af_ev_${date}_${person.toLowerCase()}_$i',
            title: '$person · ${t.title}',
            date: date,
            startTime: _hhmm(start),
            endTime: _hhmm(start + slot),
            category: isOwn ? ownCategory : teamCategory,
            priority: isOwn ? 3 : 2,
            notes: '${t.steps}\n\nOwner: $person · Week 1 plan',
            completionStatus: t.done ? 'completed' : 'pending',
            colorHex: _colors[person],
            // Reminders only for your own tasks — not for Karthik's and Harsha's.
            reminderMinutesBefore: isOwn ? 15 : -1,
          ));
        }
      }
    }
    return events;
  }
}

class _Phase {
  final String title;
  final List<_Item> items;
  _Phase(this.title, this.items);
}

class _Item {
  final String text;
  final bool done;
  _Item(this.text, {this.done = false});
}

class _Task {
  final String title;
  final String steps;
  final bool done;
  _Task(this.title, this.steps, {this.done = false});
}
