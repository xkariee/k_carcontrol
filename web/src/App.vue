<script setup lang="ts">
import { computed, h, onMounted, onUnmounted, ref } from 'vue'

type IconName =
  | 'engine'
  | 'door'
  | 'window'
  | 'neon'
  | 'lights'
  | 'seat'
  | 'hood'
  | 'trunk'
  | 'car'
  | 'close'
  | 'power'

type DoorState = {
  index: number
  label: string
  icon: IconName
  open: boolean
  available: boolean
}

type WindowState = {
  index: number
  label: string
  down: boolean
  available: boolean
}

type SeatState = {
  index: number
  label: string
  occupied: boolean
  current: boolean
}

type VehicleState = {
  visible: boolean
  focused: boolean
  vehicleName: string
  engineOn: boolean
  neonOn: boolean
  neonAvailable: boolean
  lightsMode: 0 | 1 | 2
  doors: DoorState[]
  windows: WindowState[]
  seats: SeatState[]
}

const iconPaths: Record<IconName, string[]> = {
  engine: [
    'M7 6h10l2 3v7l-2 2H8l-2-2H3v-5h3V8l1-2Z',
    'M9 3h6',
    'M10 10h4v4h-4z',
  ],
  door: [
    'M7 3h8l3 3v15H6V6l1-3Z',
    'M9 7h6v8H9z',
    'M14 18h1',
  ],
  window: [
    'M4 17 6 6l3-3h9l2 14H4Z',
    'M8 7h8l1 7H7l1-7Z',
    'm10 10 2 2 3-3',
  ],
  neon: [
    'M5 15h14l2 3H3l2-3Z',
    'm7 15 2-5h6l2 5',
    'M6 21h12',
    'M8 18v3m8-3v3',
  ],
  lights: [
    'M13 6a6 6 0 1 0 0 12V6Z',
    'M17 8h4M17 12h5M17 16h4',
  ],
  seat: [
    'M8 5a2 2 0 1 0 0-4 2 2 0 0 0 0 4Z',
    'M6 8v6l3 2h7l2 5',
    'M6 11h7l2 3v3',
    'M5 21h12',
  ],
  hood: [
    'M3 16h18l-2-7H5l-2 7Z',
    'M7 9 9 5h6l2 4',
    'M5 16v3m14-3v3',
  ],
  trunk: [
    'M4 9h16v9H4z',
    'M7 9V6h10v3',
    'M9 13h6',
  ],
  car: [
    'M5 17h14l2-5-3-5H6l-3 5 2 5Z',
    'M7 17v3m10-3v3',
    'M7 12h.01M17 12h.01',
  ],
  close: ['M6 6l12 12M18 6 6 18'],
  power: [
    'M12 2v10',
    'M6.3 5.7a8 8 0 1 0 11.4 0',
  ],
}

const Icon = (props: { name: IconName }) => h(
  'svg',
  {
    viewBox: '0 0 24 24',
    fill: 'none',
    stroke: 'currentColor',
    'stroke-width': 1.8,
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
    'aria-hidden': 'true',
  },
  iconPaths[props.name].map((path) => h('path', { d: path })),
)

const browserPreview = typeof window !== 'undefined' && !(window as any).invokeNative
const panel = ref<'doors' | 'windows' | 'seats' | null>(null)
const state = ref<VehicleState>({
  visible: browserPreview,
  focused: browserPreview,
  vehicleName: 'Sultan RS',
  engineOn: true,
  neonOn: true,
  neonAvailable: true,
  lightsMode: 1,
  doors: [
    { index: -1, label: 'Wszystkie', icon: 'car', open: false, available: true },
    { index: 0, label: 'Przód L', icon: 'door', open: false, available: true },
    { index: 1, label: 'Przód P', icon: 'door', open: false, available: true },
    { index: 2, label: 'Tył L', icon: 'door', open: false, available: true },
    { index: 3, label: 'Tył P', icon: 'door', open: false, available: true },
    { index: 4, label: 'Maska', icon: 'hood', open: true, available: true },
    { index: 5, label: 'Bagażnik', icon: 'trunk', open: false, available: true },
  ],
  windows: [
    { index: -1, label: 'Wszystkie', down: false, available: true },
    { index: 0, label: 'Przód L', down: false, available: true },
    { index: 1, label: 'Przód P', down: true, available: true },
    { index: 2, label: 'Tył L', down: false, available: true },
    { index: 3, label: 'Tył P', down: false, available: true },
  ],
  seats: [
    { index: -1, label: 'Kierowca', occupied: false, current: true },
    { index: 0, label: 'Pasażer', occupied: false, current: false },
    { index: 1, label: 'Tył lewy', occupied: false, current: false },
    { index: 2, label: 'Tył prawy', occupied: true, current: false },
  ],
})

const anyDoorOpen = computed(() => state.value.doors.some((door) => door.index >= 0 && door.open))
const anyWindowDown = computed(() => state.value.windows.some((window) => window.index >= 0 && window.down))
const lightsLabel = computed(() => ['Wyłączone', 'Mijania', 'Długie'][state.value.lightsMode])

async function nui(event: string, data: Record<string, unknown> = {}) {
  if (browserPreview) {
    applyPreviewAction(event, data)
    return
  }

  const resource = (window as any).GetParentResourceName?.() ?? 'k_carcontrol'
  await fetch(`https://${resource}/${event}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data),
  })
}

function applyPreviewAction(event: string, data: Record<string, unknown>) {
  if (event === 'toggleEngine') state.value.engineOn = !state.value.engineOn
  if (event === 'toggleWindow') {
    const index = Number(data.index)
    const target = state.value.windows.find((window) => window.index === index)
    if (index === -1) {
      const next = !anyWindowDown.value
      state.value.windows.forEach((window) => {
        if (window.index >= 0 && window.available) window.down = next
      })
    } else if (target) {
      target.down = !target.down
    }
  }
  if (event === 'toggleNeon') state.value.neonOn = !state.value.neonOn
  if (event === 'cycleLights') state.value.lightsMode = ((state.value.lightsMode + 1) % 3) as 0 | 1 | 2
  if (event === 'toggleDoor') {
    const index = Number(data.index)
    const target = state.value.doors.find((door) => door.index === index)
    if (index === -1) {
      const next = !anyDoorOpen.value
      state.value.doors.forEach((door) => {
        if (door.index >= 0 && door.available) door.open = next
      })
    } else if (target) {
      target.open = !target.open
    }
  }
  if (event === 'switchSeat') {
    state.value.seats.forEach((seat) => { seat.current = seat.index === Number(data.index) })
  }
}

function togglePanel(next: 'doors' | 'windows' | 'seats') {
  panel.value = panel.value === next ? null : next
}

function handleMessage(event: MessageEvent) {
  if (event.data?.action === 'carcontrol:update') {
    state.value = { ...state.value, ...event.data.data }
    if (!state.value.visible) panel.value = null
  }
}

function handleKeydown(event: KeyboardEvent) {
  if (event.key === 'Escape') {
    panel.value = null
    void nui('close')
  }
}

onMounted(() => {
  window.addEventListener('message', handleMessage)
  window.addEventListener('keydown', handleKeydown)
  void nui('ready')
})

onUnmounted(() => {
  window.removeEventListener('message', handleMessage)
  window.removeEventListener('keydown', handleKeydown)
})
</script>

<template>
  <Transition name="menu">
    <main v-if="state.visible" class="car-control" :class="{ 'is-focused': state.focused }">
      <Transition name="subpanel" mode="out-in">
        <section v-if="panel === 'doors'" key="doors" class="subpanel">
          <header class="subpanel__header">
            <div>
              <span>Nadwozie</span>
              <strong>Drzwi pojazdu</strong>
            </div>
            <button class="subpanel__close" aria-label="Zamknij panel" @click="panel = null">
              <Icon name="close" />
            </button>
          </header>

          <div class="subpanel__grid subpanel__grid--doors">
            <button
              v-for="door in state.doors"
              :key="door.index"
              class="detail-button"
              :class="{ 'is-active': door.index === -1 ? anyDoorOpen : door.open }"
              :disabled="!door.available"
              @click="nui('toggleDoor', { index: door.index })"
            >
              <Icon :name="door.icon" />
              <span>{{ door.label }}</span>
              <i>{{ (door.index === -1 ? anyDoorOpen : door.open) ? 'Otwarte' : 'Zamknięte' }}</i>
            </button>
          </div>
        </section>

        <section v-else-if="panel === 'windows'" key="windows" class="subpanel">
          <header class="subpanel__header">
            <div>
              <span>Wnętrze</span>
              <strong>Szyby pojazdu</strong>
            </div>
            <button class="subpanel__close" aria-label="Zamknij panel" @click="panel = null">
              <Icon name="close" />
            </button>
          </header>

          <div class="subpanel__grid subpanel__grid--windows">
            <button
              v-for="window in state.windows"
              :key="window.index"
              class="detail-button"
              :class="{ 'is-active': window.index === -1 ? anyWindowDown : window.down }"
              :disabled="!window.available"
              @click="nui('toggleWindow', { index: window.index })"
            >
              <Icon name="window" />
              <span>{{ window.label }}</span>
              <i>{{ (window.index === -1 ? anyWindowDown : window.down) ? 'Opuszczona' : 'Podniesiona' }}</i>
            </button>
          </div>
        </section>

        <section v-else-if="panel === 'seats'" key="seats" class="subpanel">
          <header class="subpanel__header">
            <div>
              <span>Wnętrze</span>
              <strong>Wybierz siedzenie</strong>
            </div>
            <button class="subpanel__close" aria-label="Zamknij panel" @click="panel = null">
              <Icon name="close" />
            </button>
          </header>

          <div class="subpanel__grid subpanel__grid--seats">
            <button
              v-for="seat in state.seats"
              :key="seat.index"
              class="detail-button detail-button--seat"
              :class="{ 'is-active': seat.current }"
              :disabled="seat.occupied && !seat.current"
              @click="nui('switchSeat', { index: seat.index })"
            >
              <Icon name="seat" />
              <span>{{ seat.label }}</span>
              <i>{{ seat.current ? 'Aktualne' : seat.occupied ? 'Zajęte' : 'Wolne' }}</i>
            </button>
          </div>
        </section>
      </Transition>

      <section class="control-bar">
        <div class="vehicle-chip">
          <span class="vehicle-chip__icon"><Icon name="car" /></span>
          <span class="vehicle-chip__copy">
            <small>Sterowanie</small>
            <strong>{{ state.vehicleName }}</strong>
          </span>
        </div>

        <div class="control-bar__divider"></div>

        <button
          class="control-button"
          :class="{ 'is-active': state.engineOn }"
          @click="nui('toggleEngine')"
        >
          <span class="control-button__icon"><Icon name="power" /></span>
          <span class="control-button__copy">
            <small>Silnik</small>
            <strong>{{ state.engineOn ? 'Włączony' : 'Wyłączony' }}</strong>
          </span>
        </button>

        <button
          class="control-button"
          :class="{ 'is-active': anyDoorOpen, 'is-selected': panel === 'doors' }"
          @click="togglePanel('doors')"
        >
          <span class="control-button__icon"><Icon name="door" /></span>
          <span class="control-button__copy">
            <small>Drzwi</small>
            <strong>{{ anyDoorOpen ? 'Otwarte' : 'Zamknięte' }}</strong>
          </span>
        </button>

        <button
          class="control-button"
          :class="{ 'is-active': anyWindowDown, 'is-selected': panel === 'windows' }"
          @click="togglePanel('windows')"
        >
          <span class="control-button__icon"><Icon name="window" /></span>
          <span class="control-button__copy">
            <small>Szyby</small>
            <strong>{{ anyWindowDown ? 'Uchylone' : 'Podniesione' }}</strong>
          </span>
        </button>

        <button
          class="control-button"
          :class="{ 'is-active': state.neonOn }"
          :disabled="!state.neonAvailable"
          @click="nui('toggleNeon')"
        >
          <span class="control-button__icon"><Icon name="neon" /></span>
          <span class="control-button__copy">
            <small>Neony</small>
            <strong>{{ state.neonAvailable ? (state.neonOn ? 'Włączone' : 'Wyłączone') : 'Brak' }}</strong>
          </span>
        </button>

        <button
          class="control-button"
          :class="{ 'is-active': state.lightsMode > 0 }"
          @click="nui('cycleLights')"
        >
          <span class="control-button__icon"><Icon name="lights" /></span>
          <span class="control-button__copy">
            <small>Światła</small>
            <strong>{{ lightsLabel }}</strong>
          </span>
          <span class="mode-dots" aria-hidden="true">
            <i v-for="mode in 3" :key="mode" :class="{ active: state.lightsMode === mode - 1 }"></i>
          </span>
        </button>

        <button
          class="control-button"
          :class="{ 'is-selected': panel === 'seats' }"
          @click="togglePanel('seats')"
        >
          <span class="control-button__icon"><Icon name="seat" /></span>
          <span class="control-button__copy">
            <small>Siedzenie</small>
            <strong>{{ state.seats.find((seat) => seat.current)?.label ?? 'Wybierz' }}</strong>
          </span>
        </button>

        <div class="shortcut">
          <kbd>F7</kbd>
          <span>{{ state.focused ? 'ESC zamyka' : 'Sterowanie' }}</span>
        </div>
      </section>
    </main>
  </Transition>
</template>
