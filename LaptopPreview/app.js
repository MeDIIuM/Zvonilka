const CONTACTS_STORAGE_KEY = "zvonilka_preview_contacts_v2";
const CALLS_STORAGE_KEY = "zvonilka_preview_calls";
const THEME_STORAGE_KEY = "zvonilka_preview_theme";

const seededContacts = [
  { id: "1", name: "Иван Петров", phones: ["+7 999 100-20-30"], photoDataUrl: "" },
  { id: "2", name: "Алина Смирнова", phones: ["+7 915 222-33-44", "+7 916 111-22-33"], photoDataUrl: "" },
  { id: "3", name: "Сервис Доставка", phones: ["8 (800) 555-35-35"], photoDataUrl: "" },
  { id: "4", name: "Мария Волкова", phones: ["+7 903 444-55-66"], photoDataUrl: "" },
  { id: "5", name: "Без номера", phones: [], photoDataUrl: "" },
  { id: "6", name: "Артем Орлов", phones: ["+7 901 101-01-01"], photoDataUrl: "" },
  { id: "7", name: "Екатерина Новикова", phones: ["+7 901 101-01-02"], photoDataUrl: "" },
  { id: "8", name: "Павел Захаров", phones: ["+7 901 101-01-03"], photoDataUrl: "" },
  { id: "9", name: "Ольга Киселева", phones: ["+7 901 101-01-04"], photoDataUrl: "" },
  { id: "10", name: "Никита Беляев", phones: ["+7 901 101-01-05"], photoDataUrl: "" },
  { id: "11", name: "Дмитрий Яковлев", phones: ["+7 901 101-01-06"], photoDataUrl: "" },
  { id: "12", name: "Татьяна Федорова", phones: ["+7 901 101-01-07"], photoDataUrl: "" },
  { id: "13", name: "Роман Соловьев", phones: ["+7 901 101-01-08"], photoDataUrl: "" },
  { id: "14", name: "Виктория Морозова", phones: ["+7 901 101-01-09"], photoDataUrl: "" },
  { id: "15", name: "Антон Кузнецов", phones: ["+7 901 101-01-10"], photoDataUrl: "" },
  { id: "16", name: "Юлия Сергеева", phones: ["+7 901 101-01-11"], photoDataUrl: "" },
  { id: "17", name: "Глеб Лебедев", phones: ["+7 901 101-01-12"], photoDataUrl: "" },
  { id: "18", name: "Инна Воронова", phones: ["+7 901 101-01-13"], photoDataUrl: "" },
  { id: "19", name: "Максим Романов", phones: ["+7 901 101-01-14"], photoDataUrl: "" },
  { id: "20", name: "Яна Тимофеева", phones: ["+7 901 101-01-15"], photoDataUrl: "" },
  { id: "21", name: "Борис Громов", phones: ["+7 901 101-01-16"], photoDataUrl: "" },
  { id: "22", name: "Людмила Авдеева", phones: ["+7 901 101-01-17"], photoDataUrl: "" },
  { id: "23", name: "Константин Ларионов", phones: ["+7 901 101-01-18"], photoDataUrl: "" },
  { id: "24", name: "Зоя Назарова", phones: ["+7 901 101-01-19"], photoDataUrl: "" },
  { id: "25", name: "Илья Гончаров", phones: ["+7 901 101-01-20"], photoDataUrl: "" }
];

const listEl = document.getElementById("contactsList");
const searchEl = document.getElementById("searchInput");
const rowTemplate = document.getElementById("contactRowTemplate");

const openSettingsBtn = document.getElementById("openSettings");
const closeSettingsBtn = document.getElementById("closeSettings");
const settingsModal = document.getElementById("settingsModal");
const resetStatsInSettingsBtn = document.getElementById("resetStatsInSettings");
const themeInputs = Array.from(document.querySelectorAll('input[name="theme"]'));

const editModal = document.getElementById("editModal");
const closeEditBtn = document.getElementById("closeEdit");
const editForm = document.getElementById("editForm");
const editFirstNameEl = document.getElementById("editFirstName");
const editLastNameEl = document.getElementById("editLastName");
const editPhoneEl = document.getElementById("editPhone");
const editPhotoInputEl = document.getElementById("editPhotoInput");
const editPhotoPreviewEl = document.getElementById("editPhotoPreview");
const removePhotoBtn = document.getElementById("removePhotoBtn");

let contacts = loadContacts();
let calls = loadCalls();
let query = "";
let theme = loadTheme();
let editingContactId = null;
let editingPhotoDataUrl = "";

applyTheme(theme);
render();

searchEl.addEventListener("input", (event) => {
  query = event.target.value.trim().toLowerCase();
  render();
});

openSettingsBtn.addEventListener("click", openSettings);
closeSettingsBtn.addEventListener("click", closeSettings);

settingsModal.addEventListener("click", (event) => {
  if (event.target.dataset.close === "true") {
    closeSettings();
  }
});

resetStatsInSettingsBtn.addEventListener("click", () => {
  calls = {};
  localStorage.setItem(CALLS_STORAGE_KEY, JSON.stringify(calls));
  render();
  closeSettings();
});

for (const input of themeInputs) {
  input.checked = input.value === theme;
  input.addEventListener("change", () => {
    if (!input.checked) return;
    theme = input.value;
    localStorage.setItem(THEME_STORAGE_KEY, theme);
    applyTheme(theme);
  });
}

closeEditBtn.addEventListener("click", closeEdit);

editModal.addEventListener("click", (event) => {
  if (event.target.dataset.closeEdit === "true") {
    closeEdit();
  }
});

editPhotoInputEl.addEventListener("change", onPhotoSelected);

removePhotoBtn.addEventListener("click", () => {
  editingPhotoDataUrl = "";
  editPhotoInputEl.value = "";
  syncEditPhotoPreview();
});

editForm.addEventListener("submit", (event) => {
  event.preventDefault();
  saveEditedContact();
});

function openSettings() {
  settingsModal.classList.add("is-open");
  settingsModal.setAttribute("aria-hidden", "false");
}

function closeSettings() {
  settingsModal.classList.remove("is-open");
  settingsModal.setAttribute("aria-hidden", "true");
}

function applyTheme(nextTheme) {
  document.body.dataset.theme = nextTheme;
}

function render() {
  const prepared = contacts
    .map((contact) => {
      const primaryPhone = firstPhone(contact.phones);
      return {
        ...contact,
        primaryPhone,
        outgoingCallsCount: primaryPhone ? countFor(contact.id, primaryPhone) : 0
      };
    })
    .filter((contact) => !!contact.primaryPhone)
    .filter((contact) => {
      if (!query) return true;
      return (
        contact.name.toLowerCase().includes(query) ||
        contact.primaryPhone.toLowerCase().includes(query)
      );
    })
    .sort((a, b) => {
      if (a.outgoingCallsCount !== b.outgoingCallsCount) {
        return b.outgoingCallsCount - a.outgoingCallsCount;
      }
      return a.name.localeCompare(b.name, "ru");
    });

  listEl.innerHTML = "";

  for (const contact of prepared) {
    const row = rowTemplate.content.firstElementChild.cloneNode(true);
    const avatar = row.querySelector(".avatar");
    const name = row.querySelector(".name");
    const meta = row.querySelector(".meta");
    const callBtn = row.querySelector(".call-btn");

    fillAvatar(avatar, contact);

    name.textContent = contact.name;
    meta.textContent = `Исходящих: ${contact.outgoingCallsCount}`;

    row.addEventListener("click", () => {
      openEdit(contact.id);
    });

    callBtn.addEventListener("click", (event) => {
      event.stopPropagation();
      registerOutgoingTap(contact.id, contact.primaryPhone);
      tryCall(contact.primaryPhone);
      render();
    });

    listEl.appendChild(row);
  }

  if (prepared.length === 0) {
    listEl.innerHTML = `<li class="empty-state">Ничего не найдено</li>`;
  }
}

function fillAvatar(avatarEl, contact) {
  if (contact.photoDataUrl) {
    avatarEl.textContent = "";
    avatarEl.style.background = `center / cover no-repeat url("${contact.photoDataUrl}")`;
    return;
  }

  avatarEl.textContent = initials(contact.name);
  avatarEl.style.background = avatarColor(contact.id);
}

function openEdit(contactId) {
  const contact = contacts.find((item) => item.id === contactId);
  if (!contact) return;

  editingContactId = contactId;
  const split = splitName(contact.name);
  editFirstNameEl.value = split.firstName;
  editLastNameEl.value = split.lastName;
  editPhoneEl.value = firstPhone(contact.phones) || "";
  editingPhotoDataUrl = contact.photoDataUrl || "";
  editPhotoInputEl.value = "";
  syncEditPhotoPreview();

  editModal.classList.add("is-open");
  editModal.setAttribute("aria-hidden", "false");
}

function closeEdit() {
  editingContactId = null;
  editModal.classList.remove("is-open");
  editModal.setAttribute("aria-hidden", "true");
}

function saveEditedContact() {
  if (!editingContactId) return;

  const firstName = editFirstNameEl.value.trim();
  const lastName = editLastNameEl.value.trim();
  const phone = editPhoneEl.value.trim();

  if (!firstName || !phone) {
    return;
  }

  const fullName = [firstName, lastName].filter(Boolean).join(" ");

  contacts = contacts.map((contact) => {
    if (contact.id !== editingContactId) return contact;
    return {
      ...contact,
      name: fullName,
      phones: [phone],
      photoDataUrl: editingPhotoDataUrl || ""
    };
  });

  persistContacts();
  render();
  closeEdit();
}

function onPhotoSelected(event) {
  const file = event.target.files?.[0];
  if (!file) return;

  const reader = new FileReader();
  reader.onload = () => {
    const value = typeof reader.result === "string" ? reader.result : "";
    editingPhotoDataUrl = value;
    syncEditPhotoPreview();
  };
  reader.readAsDataURL(file);
}

function syncEditPhotoPreview() {
  if (editingPhotoDataUrl) {
    editPhotoPreviewEl.src = editingPhotoDataUrl;
  } else {
    editPhotoPreviewEl.src =
      "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='72' height='72'%3E%3Crect width='100%25' height='100%25' fill='%23dce7ea'/%3E%3Ctext x='50%25' y='52%25' dominant-baseline='middle' text-anchor='middle' font-family='Arial' font-size='12' fill='%2360727b'%3ENo photo%3C/text%3E%3C/svg%3E";
  }
}

function splitName(fullName) {
  const parts = String(fullName || "").trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) {
    return { firstName: "", lastName: "" };
  }

  const [firstName, ...rest] = parts;
  return {
    firstName,
    lastName: rest.join(" ")
  };
}

function registerOutgoingTap(contactId, phoneNumber) {
  const key = statKey(contactId, phoneNumber);
  calls[key] = (calls[key] || 0) + 1;
  localStorage.setItem(CALLS_STORAGE_KEY, JSON.stringify(calls));
}

function tryCall(phoneNumber) {
  const sanitized = phoneNumber.replace(/[^+\d]/g, "");
  if (!sanitized) return;
  window.location.href = `tel:${sanitized}`;
}

function countFor(contactId, phoneNumber) {
  return calls[statKey(contactId, phoneNumber)] || 0;
}

function statKey(contactId, phoneNumber) {
  return `${contactId}_${phoneNumber.replace(/\D/g, "")}`;
}

function firstPhone(phones) {
  if (!Array.isArray(phones)) return null;
  return phones.find((phone) => typeof phone === "string" && phone.trim().length > 0) || null;
}

function initials(name) {
  const letters = name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
  return letters || "?";
}

function avatarColor(seed) {
  const palette = ["#006b63", "#286aa8", "#805b2d", "#8d3f56", "#4a6f23"];
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash << 5) - hash + seed.charCodeAt(i);
    hash |= 0;
  }
  return palette[Math.abs(hash) % palette.length];
}

function loadContacts() {
  const raw = localStorage.getItem(CONTACTS_STORAGE_KEY);
  if (!raw) {
    localStorage.setItem(CONTACTS_STORAGE_KEY, JSON.stringify(seededContacts));
    return seededContacts;
  }

  try {
    const parsed = JSON.parse(raw);
    const list = Array.isArray(parsed) ? parsed : seededContacts;
    return list.map((contact) => ({
      ...contact,
      photoDataUrl: typeof contact.photoDataUrl === "string" ? contact.photoDataUrl : ""
    }));
  } catch {
    return seededContacts;
  }
}

function persistContacts() {
  localStorage.setItem(CONTACTS_STORAGE_KEY, JSON.stringify(contacts));
}

function loadCalls() {
  const raw = localStorage.getItem(CALLS_STORAGE_KEY);
  if (!raw) return {};

  try {
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

function loadTheme() {
  const stored = localStorage.getItem(THEME_STORAGE_KEY);
  if (stored === "dark" || stored === "light") {
    return stored;
  }
  return "light";
}
