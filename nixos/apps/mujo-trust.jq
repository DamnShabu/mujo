# The trust registry's state machine. Every transition a record can go through
# is defined here and nowhere else; mujo-trust-registry.sh is the only caller,
# and it is also what the self-check drives, so the test runs these functions
# rather than a copy of them.
#
# The record's shape is read directly by quickshell/mujo.sh and lib/security.sh,
# so fields may be added but never renamed.

def now_iso: (now | todate);

def new_record($name; $tier; $path):
  { name: $name,
    tier: $tier,
    state: "QUARANTINE",
    store_path: $path,
    previous_store_path: null,
    observed_seconds: 0,
    session_started: null,
    registered_at: now_iso,
    last_evaluated: now_iso,
    violations: 0,
    violation_log: [] };

# An application is identified by its store path, which is a hash of its
# content and its whole build closure. A rebuilt or updated package is a
# different application, and docs/application-trust.md §5 requires it to
# start its evaluation over -- while the path that was trusted stays
# recorded, because that is what a rollback returns to.
def requarantine($path):
  .previous_store_path = .store_path
  | .store_path = $path
  | .state = "QUARANTINE"
  | .observed_seconds = 0
  | .session_started = null
  | .last_evaluated = now_iso;

# The runtime a state maps to. This is the whole point of the engine:
# nothing else in the system decides where an application runs.
def runtime_for:
  if .state == "REVOKED" then "denied"
  elif .state == "GRADUATED" then "native"
  else "quarantine" end;

# Credit a running session's time so far, and keep it running.
def bank_session:
  if .session_started == null then .
  else .observed_seconds += ((now - .session_started) | floor)
       | .session_started = now
  end;

def valid_tier($t):
  if ["low", "medium", "high", "critical"] | index($t) then .
  else error("tier must be low, medium, high or critical, not '\($t)'") end;

# Administrative verbs act on a record that exists. Creating one as a side
# effect left partial records with no store_path behind.
def known($a):
  if .applications[$a] == null then error("'\($a)' is not registered") else . end;

def admin_note($action; $from; $to):
  .admin_log = ((.admin_log // []) + [{ at: now_iso, action: $action, from: $from, to: $to }]);

# ── socket verbs: what an application may say about itself ──────────────

def begin($a; $p):
  if .applications[$a] == null
  then .applications[$a] = new_record($a; "medium"; $p)
  elif .applications[$a].store_path != $p
  then .applications[$a] |= requarantine($p)
  else . end
  # Only one accumulator per application: parallel launches must not
  # let an application bank several hours per hour of real time.
  | if .applications[$a].session_started == null
    then .applications[$a].session_started = now
    else . end;

def end_session($a):
  if .applications[$a].session_started == null then . else
    .applications[$a].observed_seconds +=
      ((now - .applications[$a].session_started) | floor)
    | .applications[$a].session_started = null
  end;

# Any reported boundary violation revokes immediately. Deciding whether it
# was a false positive is a human's job. An unknown name is a no-op, which is
# what lets tests/trust probe the socket without revoking anything real.
def violation($a; $r):
  if .applications[$a] == null then . else
    .applications[$a].violations += 1
    | .applications[$a].state = "REVOKED"
    | .applications[$a].last_evaluated = now_iso
    | .applications[$a].violation_log += [{ at: now_iso, reason: $r }]
  end;

# ── policy ──────────────────────────────────────────────────────────────
#
# Time alone never graduates anything (Phase 20): a clean violation record is
# also required, CRITICAL never leaves quarantine and HIGH never leaves
# observation without a person saying so.
def evaluate($quarantine; $observing):
  .applications |= with_entries(.value |= (
    bank_session
    | if .violations > 0 then .
      elif .state == "QUARANTINE"
           and .observed_seconds >= $quarantine
           and .tier != "critical"
      then .state = "OBSERVING" | .last_evaluated = now_iso
      elif .state == "OBSERVING"
           and .observed_seconds >= ($quarantine + $observing)
           and (.tier == "low" or .tier == "medium")
      then .state = "GRADUATED" | .last_evaluated = now_iso
      else . end));

# Declarative seeding runs on every boot. A REVOKED record is a violation
# verdict, not an initial state, so the declared state never overrides it:
# re-asserting GRADUATED here used to silently undo each revocation the
# broker had made. `mujo-trust rollback`/`graduate` are the ways back.
def seed($a; $t; $s; $p):
  if .applications[$a] == null then
    .applications[$a] = (new_record($a; $t; $p) | .state = $s)
  elif .applications[$a].store_path != $p then
    .applications[$a] |= (
      .state as $was
      | requarantine($p)
      | if $s != "QUARANTINE" and $was != "REVOKED" then .state = $s else . end)
  else
    .applications[$a] |= (
      .tier = $t
      | if $s != "QUARANTINE" and .state != "REVOKED" then .state = $s else . end)
  end;

# ── administration (root) ───────────────────────────────────────────────

# Registering an existing name used to overwrite it, erasing its REVOKED
# state and its violation log with it.
def register($a; $t; $p):
  valid_tier($t)
  | if .applications[$a] != null
    then error("'\($a)' is already registered; use `mujo-trust tier` to change its tier")
    else .applications[$a] = new_record($a; $t; $p) end;

def set_tier($a; $t):
  known($a) | valid_tier($t)
  | .applications[$a] |= (admin_note("tier"; .tier; $t) | .tier = $t);

# A forced QUARANTINE also discards the observation already banked. Keeping it
# meant the next evaluator pass moved the application straight back to
# OBSERVING and then GRADUATED, undoing the administrator within the hour.
def set_state($a; $s):
  known($a)
  | .applications[$a] |= (
      admin_note("state"; .state; $s)
      | .state = $s
      | .last_evaluated = now_iso
      | if $s == "QUARANTINE" then .observed_seconds = 0 | .session_started = null else . end);

# The old closure is still in the Nix store until it is garbage collected,
# which is what makes rollback a lookup rather than a rebuild. The caller
# checks that $prev still exists; this only rewrites the record.
def rollback($a; $prev):
  known($a)
  | .applications[$a] |= (
      admin_note("rollback"; .store_path; $prev)
      | .store_path = $prev
      | .previous_store_path = null
      | .state = "GRADUATED"
      | .violations = 0
      | .last_evaluated = now_iso);
