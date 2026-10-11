(function () {
  'use strict';
  const $ = (selector, root = document) => root.querySelector(selector);
  const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
  const modal = $('#authModal');
  const form = $('#authForm');
  const registerFields = $('#registerFields');
  const termsLabel = $('#termsLabel');
  const title = $('#modalTitle');
  const subtitle = $('#modalSubtitle');
  const submit = $('#authSubmit');
  const switcher = $('#authSwitch');
  const message = $('#authMessage');
  let mode = 'login';
  let supabaseClient = null;
  const config = window.ARTFOS_CONFIG || {};

  $('#year').textContent = String(new Date().getFullYear());
  if (window.supabase && config.supabaseUrl && config.supabaseAnonKey) {
    supabaseClient = window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, {
      auth: { autoRefreshToken: true, persistSession: true, detectSessionInUrl: true }
    });
  }

  function showMessage(text, type) {
    message.textContent = text;
    message.className = 'auth-message' + (type ? ' ' + type : '');
    message.hidden = false;
  }
  function clearMessage() { message.hidden = true; message.textContent = ''; message.className = 'auth-message'; }
  function openModal(nextMode) {
    mode = nextMode === 'register' ? 'register' : 'login';
    modal.hidden = false;
    document.body.style.overflow = 'hidden';
    clearMessage();
    form.reset();
    const registering = mode === 'register';
    registerFields.hidden = !registering;
    termsLabel.hidden = !registering;
    $$('input', registerFields).forEach(input => { input.required = registering; });
    $('input[name="terms"]', termsLabel).required = registering;
    title.textContent = registering ? 'Daftar member' : 'Masuk ke akun';
    subtitle.textContent = registering ? 'Lengkapi data Anda. Akses aktif setelah verifikasi admin.' : 'Gunakan akun member ARTFOS GOLD Anda.';
    submit.innerHTML = registering ? 'Kirim pendaftaran <span>→</span>' : 'Masuk <span>→</span>';
    switcher.innerHTML = registering ? 'Sudah punya akun? <button type="button" data-view="login">Masuk</button>' : 'Belum punya akun? <button type="button" data-view="register">Daftar member</button>';
    if (!supabaseClient) showMessage('Mode koneksi belum diatur. Isi config.js dan siapkan database Supabase sebelum menerima pendaftaran member.', 'error');
    setTimeout(() => $(registering ? 'input[name="fullName"]' : 'input[name="email"]').focus(), 50);
  }
  function closeModal() { modal.hidden = true; document.body.style.overflow = ''; }
  document.addEventListener('click', event => {
    const viewButton = event.target.closest('[data-view]');
    if (viewButton) { event.preventDefault(); openModal(viewButton.dataset.view); }
  });
  $('#closeModal').addEventListener('click', closeModal);
  modal.addEventListener('click', event => { if (event.target === modal) closeModal(); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && !modal.hidden) closeModal(); });
  $('#menuToggle').addEventListener('click', () => {
    const nav = $('#mainNav');
    const open = nav.classList.toggle('open');
    $('#menuToggle').setAttribute('aria-expanded', String(open));
  });
  $$('#mainNav a').forEach(link => link.addEventListener('click', () => {
    $('#mainNav').classList.remove('open');
    $('#menuToggle').setAttribute('aria-expanded', 'false');
  }));

  form.addEventListener('submit', async event => {
    event.preventDefault();
    clearMessage();
    if (!supabaseClient) {
      showMessage('Pendaftaran/login belum dapat diproses karena Supabase belum dikonfigurasi. Tidak ada data yang dikirim atau disimpan.', 'error');
      return;
    }
    const data = new FormData(form);
    const email = String(data.get('email') || '').trim().toLowerCase();
    const password = String(data.get('password') || '');
    submit.disabled = true;
    submit.textContent = 'Memproses…';
    try {
      if (mode === 'register') {
        const metadata = {
          full_name: String(data.get('fullName') || '').trim(),
          phone: String(data.get('phone') || '').trim(),
          username: String(data.get('username') || '').trim(),
          broker_name: String(data.get('broker') || '').trim(),
          broker_account: String(data.get('brokerAccount') || '').trim()
        };
        const { data: result, error } = await supabaseClient.auth.signUp({ email, password, options: { data: metadata } });
        if (error) throw error;
        if (result.user && result.session) {
          showMessage('Pendaftaran diterima. Status akun menunggu pemeriksaan admin.', 'success');
        } else {
          showMessage('Pendaftaran dibuat. Periksa email untuk konfirmasi, lalu tunggu verifikasi admin.', 'success');
        }
      } else {
        const { data: result, error } = await supabaseClient.auth.signInWithPassword({ email, password });
        if (error) throw error;
        const { data: profile, error: profileError } = await supabaseClient.from('member_profiles')
          .select('full_name,approval_status,membership,role').eq('user_id', result.user.id).maybeSingle();
        if (profileError) throw profileError;
        renderAccount(result.user, profile);
        closeModal();
      }
    } catch (error) {
      showMessage(error && error.message ? error.message : 'Permintaan gagal. Periksa konfigurasi dan coba lagi.', 'error');
    } finally {
      submit.disabled = false;
      submit.innerHTML = mode === 'register' ? 'Kirim pendaftaran <span>→</span>' : 'Masuk <span>→</span>';
    }
  });

  function renderAccount(user, profile) {
    const existing = $('#accountView');
    if (existing) existing.remove();
    const root = document.createElement('section');
    root.id = 'accountView';
    root.className = 'dashboard-view';
    const name = profile && profile.full_name ? profile.full_name : user.email;
    const status = profile && profile.approval_status ? profile.approval_status : 'pending';
    const membership = profile && profile.membership ? profile.membership : 'gratis';
    root.innerHTML = '<div class="dashboard-top"><div><div class="eyebrow">MEMBER AREA</div><h1>Selamat datang.</h1><p id="accountName"></p></div><button class="btn btn-ghost" id="logoutBtn">Keluar</button></div>' +
      '<div class="dashboard-card"><h3>Status akun</h3><p id="accountStatus"></p><p id="accountPlan"></p><p>Signal hanya tersedia untuk akun yang telah disetujui dan sesuai hak membership. Data pasar dan hasil akan muncul setelah provider serta signal engine dihubungkan.</p></div>' +
      '<div class="dashboard-card"><h3>Signal terbaru</h3><p id="signalStatus"></p><div class="table-wrap"><table class="signal-table"><thead><tr><th>INSTRUMEN</th><th>ARAH</th><th>ZONA</th><th>STOP LOSS</th><th>TARGET</th><th>STATUS</th></tr></thead><tbody id="signalRows"></tbody></table></div></div>' +
      '<div class="dashboard-card"><h3>Statistik performa</h3><p>Net result: — USD · Profit total: — USD · Loss total: — USD. Statistik akan ditampilkan hanya dari hasil yang tercatat dan terverifikasi.</p></div>';
    $('#home').insertAdjacentElement('afterend', root);
    $('#accountName', root).textContent = name;
    $('#accountStatus', root).textContent = status === 'approved' ? 'Disetujui' : 'Menunggu persetujuan admin';
    $('#accountPlan', root).textContent = 'Membership: ' + membership.toUpperCase();
    $('#signalStatus', root).textContent = status === 'approved' ? 'Belum ada signal aktif yang dapat ditampilkan.' : 'Signal terkunci sampai akun disetujui admin.';
    $('#logoutBtn', root).addEventListener('click', async () => {
      const { error } = await supabaseClient.auth.signOut();
      if (error) { alert(error.message); return; }
      root.remove();
      window.scrollTo({ top: 0, behavior: 'smooth' });
    });
    if (profile && profile.role === 'admin') {
      const admin = document.createElement('div'); admin.className = 'dashboard-card';
      admin.innerHTML = '<h3>Admin</h3><p>Akun memiliki role admin di database. Pengelolaan admin harus dibangun dengan kebijakan RLS yang benar sebelum operasi produksi.</p>';
      root.appendChild(admin);
    }
    root.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
  if (supabaseClient) {
    supabaseClient.auth.getSession().then(({ data }) => {
      if (data && data.session) supabaseClient.from('member_profiles').select('full_name,approval_status,membership,role').eq('user_id', data.session.user.id).maybeSingle()
        .then(({ data: profile }) => renderAccount(data.session.user, profile));
    }).catch(() => {});
  }
})();
