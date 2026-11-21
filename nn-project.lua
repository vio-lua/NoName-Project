--[[
================================================================================
 NN-Project (No Name Project) - клиентский косметический фреймворк для Roblox
 Build 1.0.2 | Opus
================================================================================
 ТИП СКРИПТА : LocalScript (или клиентский скрипт инжектора)
 Всё работает ТОЛЬКО на клиенте: никаких RemoteEvent, геймплей не затрагивается.
 Интерфейс создаётся в PlayerGui.

 ЧТО НОВОГО В 1.1 F1:
   * Предупреждение -> отсчёт 6 сек -> интро NN Project -> уведомление "Загрузка"
   * Меню уменьшено, кнопка открытия убрана: меню открывается кликом по ватермарке
   * Таргет-эффект при наведении на игрока (аура + панель HP/ник/Display Name)
   * Орбитальная аура, светящаяся шляпа, волны при ходьбе, снег, светлячки
   * Плащ (один блок) ИЛИ крылья (Neon/Forcefield) - выбираются через "[Выбор]"
   * Туман, цветокоррекция, время суток, FOV
   * Эффект смерти (частицы + молния) для себя и других игроков
   * Звуки интерфейса, 7 стилей интерфейса, раздел "О скрипте"
 УПРАВЛЕНИЕ: клик по ватермарке "NN-Hub" или RightShift / Insert.
================================================================================
]]

-- ============================================================================
-- 0. СЕРВИСЫ И ЗАЩИТА ОТ ПОВТОРНОГО ЗАПУСКА
-- ============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")
local Debris = game:GetService("Debris")
local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

if _G.NNProject and type(_G.NNProject.Unload) == "function" then
	pcall(_G.NNProject.Unload)
end

-- ============================================================================
-- 0.1 ВЫБОР ЯЗЫКА И ОКНО ПОДТВЕРЖДЕНИЯ (выполняется до сборки интерфейса)
-- Язык выбирается один раз и после "Continue / Продолжить" уже не меняется:
-- для смены языка скрипт нужно перезапустить.
-- Подпись кнопки языка всегда на ДРУГОМ языке: при ENG - "Выбери язык", при RUS - "Select Language".
-- ============================================================================
local SHOW_WARNING = true

local function RunLanguageAndWarning()
	local lang = "ENG"
	pcall(function()
		local id = game:GetService("LocalizationService").RobloxLocaleId
		if type(id) == "string" and string.sub(id, 1, 2) == "ru" then
			lang = "RUS" -- язык по умолчанию определяется по локали Roblox
		end
	end)
	if not SHOW_WARNING then
		return lang
	end

	local TEXT = {
		ENG = {
			heading = "⛔ WARNING",
			title = "READ THIS",
			body = "This script is only a ClientSide visual: it is not an exploit and not a fly/ESP/Aim script. Its only purpose is to decorate your gameplay.\n\nBy launching it, you confirm that you take full responsibility for your account and for any ban.",
			agree = "I agree",
			go = "Continue",
			pick = "Выбери язык:",
		},
		RUS = {
			heading = "⛔ ВНИМАНИЕ",
			title = "ПРОЧИТАЙТЕ",
			body = "Скрипт является всего лишь ClientSide-визуалом: он не является эксплойтом, а также fly/ESP/Aim-скриптом. Цель скрипта - всего лишь украсить ваш игровой процесс.\n\nПосле запуска вы подтверждаете, что берёте на себя ответственность за ваш аккаунт и его блокировку.",
			agree = "Подтверждаю",
			go = "Продолжить",
			pick = "Select Language:",
		},
	}

	local BG, PANEL, IND = Color3.fromRGB(27, 24, 29), Color3.fromRGB(35, 32, 38), Color3.fromRGB(85, 80, 90)
	local STROKE, ON, MUTED = Color3.fromRGB(52, 48, 58), Color3.fromRGB(125, 95, 215), Color3.fromRGB(140, 138, 148)
	local ERRC, WHITE = Color3.fromRGB(235, 84, 96), Color3.fromRGB(255, 255, 255)

	local function mk(class, props, children)
		local inst = Instance.new(class)
		local parent
		for k, v in pairs(props) do
			if k == "Parent" then
				parent = v
			else
				inst[k] = v
			end
		end
		for _, child in ipairs(children or {}) do
			child.Parent = inst
		end
		inst.Parent = parent
		return inst
	end
	local function round(inst, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = radius
		c.Parent = inst
		return inst
	end
	local function tw(inst, info, goal)
		local t = game:GetService("TweenService"):Create(inst, info, goal)
		t:Play()
		return t
	end
	local fast = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local quint = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local quintIn = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	local back = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local slow = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	local old = PlayerGui:FindFirstChild("NNProject_Boot")
	if old then
		old:Destroy()
	end
	local gui = mk("ScreenGui", {
		Name = "NNProject_Boot", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = PlayerGui,
	})
	local dim = mk("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), Active = true, Parent = gui,
	})

	-- масштаб окна: на телефоне дополнительно 80%
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local mobile = game:GetService("UserInputService").TouchEnabled and not game:GetService("UserInputService").KeyboardEnabled
	local scale = math.clamp(math.min(vp.X / 440, vp.Y / 362), 0.5, 1.2) * (mobile and 0.8 or 1)
	local holder = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1, Parent = dim,
	})
	local uiscale = Instance.new("UIScale")
	uiscale.Scale = scale
	uiscale.Parent = holder

	local win = mk("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 24), Size = UDim2.fromOffset(400, 322),
		BackgroundColor3 = BG, BorderSizePixel = 0, GroupTransparency = 1, Parent = holder,
	})
	round(win, UDim.new(0, 18))
	mk("UIStroke", { Color = STROKE, Thickness = 1, Transparency = 0.3, Parent = win })

	local heading = mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(240, 20),
		Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = ERRC, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", Parent = win,
	})
	local title = mk("TextLabel", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(300, 28), Font = Enum.Font.GothamBold, TextSize = 21, TextColor3 = WHITE, Text = "", Parent = win,
	})
	local body = mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 80), Size = UDim2.new(1, -44, 0, 132),
		Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = MUTED, TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "", Parent = win,
	})

	-- переключатель языка: подпись + ENG / RUS
	local pickLabel = mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 220), Size = UDim2.fromOffset(200, 26),
		Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		Text = "", Parent = win,
	})
	local segment = round(mk("Frame", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 220), Size = UDim2.fromOffset(122, 26),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, Parent = win,
	}), UDim.new(1, 0))
	local langButtons = {}
	for i, code in ipairs({ "ENG", "RUS" }) do
		langButtons[code] = round(mk("TextButton", {
			Position = UDim2.fromOffset(3 + (i - 1) * 58, 3), Size = UDim2.fromOffset(56, 20), BorderSizePixel = 0,
			AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = MUTED,
			BackgroundColor3 = ON, BackgroundTransparency = 1, Text = code, Parent = segment,
		}), UDim.new(1, 0))
	end

	-- галочка "Подтверждаю / I agree" (круг с нарисованной галочкой) и кнопка продолжения
	local check = mk("TextButton", {
		BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(20, 266), Size = UDim2.fromOffset(190, 34), Parent = win,
	})
	local circle = round(mk("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(26, 26),
		BackgroundColor3 = PANEL, BorderSizePixel = 0, Parent = check,
	}), UDim.new(1, 0))
	local circleStroke = mk("UIStroke", { Color = IND, Thickness = 2, Parent = circle })
	local checkFill = round(mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0, 0),
		BackgroundColor3 = ON, BorderSizePixel = 0, Parent = circle,
	}), UDim.new(1, 0))
	local arms = {}
	for _, def in ipairs({ { 7.5, 14.5, 8, -45 }, { 14.5, 12, 15, 42 } }) do
		arms[#arms + 1] = round(mk("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(def[1], def[2] - 1), Size = UDim2.fromOffset(3, def[3]),
			Rotation = def[4], BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3, Parent = circle,
		}), UDim.new(1, 0))
	end
	local checkLabel = mk("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(1, -36, 1, 0), Font = Enum.Font.GothamMedium,
		TextSize = 14, TextColor3 = MUTED, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = check,
	})
	local continue = round(mk("TextButton", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 264), Size = UDim2.fromOffset(130, 36),
		BackgroundColor3 = PANEL, AutoButtonColor = false, Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = MUTED, Text = "", Parent = win,
	}), UDim.new(1, 0))

	local confirmed, finished = false, false
	local function refreshTexts()
		local t = TEXT[lang]
		heading.Text, title.Text, body.Text = t.heading, t.title, t.body
		checkLabel.Text, continue.Text, pickLabel.Text = t.agree, t.go, t.pick
		for code, button in pairs(langButtons) do
			local selected = code == lang
			tw(button, fast, { BackgroundTransparency = selected and 0 or 1, TextColor3 = selected and WHITE or MUTED })
		end
	end
	local function paintConfirm()
		tw(checkFill, back, { Size = confirmed and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 0) })
		for _, arm in ipairs(arms) do
			tw(arm, fast, { BackgroundTransparency = confirmed and 0 or 1 })
		end
		tw(circleStroke, fast, { Color = confirmed and ON or IND })
		tw(checkLabel, fast, { TextColor3 = confirmed and WHITE or MUTED })
		tw(continue, fast, { BackgroundColor3 = confirmed and ON or PANEL, TextColor3 = confirmed and WHITE or MUTED })
	end

	for code, button in pairs(langButtons) do
		button.Activated:Connect(function()
			lang = code
			refreshTexts()
		end)
	end
	check.Activated:Connect(function()
		confirmed = not confirmed
		paintConfirm()
	end)
	continue.Activated:Connect(function()
		if not confirmed then
			circleStroke.Color = ERRC
			tw(circleStroke, slow, { Color = IND })
			return
		end
		finished = true
	end)

	refreshTexts()
	tw(dim, quint, { BackgroundTransparency = 0.4 })
	tw(win, quint, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) })
	while not finished do
		task.wait(0.05)
	end

	-- язык зафиксирован: окно закрывается
	tw(win, quintIn, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 20) })
	local out = tw(dim, quintIn, { BackgroundTransparency = 1 })
	out.Completed:Wait()
	gui:Destroy()
	return lang
end

local Lang = RunLanguageAndWarning() -- "ENG" или "RUS"

local EN = {
	["Зелёный"] = "Green",
	["Красный"] = "Red",
	["Серый"] = "Gray",
	["Синий"] = "Blue",
	["Фиолетовый"] = "Purple",
	["Розовый"] = "Pink",
	["Голубой"] = "Light blue",
	["Низкая"] = "Low",
	["Средняя"] = "Medium",
	["Высокая"] = "High",
	["Белый"] = "White",
	["Чёрный"] = "Black",
	["Золотой"] = "Gold",
	["Лёгкий"] = "Light",
	["Средний"] = "Medium",
	["Сильный"] = "Heavy",
	["Игровое"] = "Default",
	["Рассвет"] = "Dawn",
	["День"] = "Day",
	["Закат"] = "Sunset",
	["Ночь"] = "Night",
	["Игровой"] = "Default",
	["Выкл"] = "Off",
	["Густой"] = "Thick",
	["Кастом."] = "Custom.",
	["Нет"] = "None",
	["Кино"] = "Cinema",
	["Холодная"] = "Cold",
	["Тёплая"] = "Warm",
	["Ч/Б"] = "B/W",
	["Яркая"] = "Vivid",
	["Мрачная"] = "Gloomy",
	["Дуги"] = "Arcs",
	["Кольца"] = "Rings",
	["Дуги + кольца"] = "Arcs + rings",
	["Все"] = "All",
	["Только я"] = "Only me",
	["Только другие"] = "Only others",
	["[NN-Project] Ошибка в модуле: "] = "[NN-Project] Module error: ",
	["Неон-фиолет"] = "Neon purple",
	["Мята"] = "Mint",
	["Лайм"] = "Lime",
	["Радуга"] = "Rainbow",
	["Ошибка"] = "Error",
	["Уведомления"] = "Notifications",
	["Код ошибки: "] = "Error code: ",
	["Описание сообщения"] = "Message description",
	["Бот / Rig: "] = "Bot / Rig: ",
	["Опасный импульс погашен."] = "Dangerous impulse neutralized.",
	["Плащ"] = "Cape",
	["Экипировка"] = "Gear",
	["Не удалось %s «%s».\n%s"] = "Failed to %s «%s».\n%s",
	["включить"] = "enable",
	["выключить"] = "disable",
	["Сбой модуля"] = "Module failure",
	["Модуль «%s» успешно %s."] = "Module «%s» successfully %s.",
	["включён"] = "enabled",
	["выключен"] = "disabled",
	["Готово"] = "Done",
	["Запуск"] = "Run",
	["Не удалось выполнить действие «"] = "Failed to perform action «",
	["Сбой действия"] = "Action failed",
	["Недоступно"] = "Unavailable",
	["Не удалось применить «"] = "Failed to apply «",
	["Сбой настройки"] = "Setting failed",
	["Тестовое уведомление. Визуальные эффекты работают корректно."] = "Test notification. Visual effects are working correctly.",
	["Проверка"] = "Test",
	["Это тестовая ошибка: так выглядят сообщения о сбоях модулей."] = "This is a test error: this is how module failure messages look.",
	["файл конфига повреждён"] = "config file is corrupted",
	["Выберите нужный вам FOV, в который должны попадать конечности игрока"] = "Choose the FOV that the player's limbs must fall into",
	["ВИЗУАЛЫ"] = "VISUALS",
	["Персонаж"] = "Character",
	["Следы движения"] = "Motion trails",
	["Неоновые ленты за руками и ногами"] = "Neon ribbons behind hands and feet",
	["Аура частиц"] = "Particle aura",
	["Частицы и свечение вокруг тела"] = "Particles and glow around the body",
	["Орбитальная аура"] = "Orbital aura",
	["Шары с лентами, покачиваются при ходьбе"] = "Orbs with ribbons that bounce as you walk",
	["Светящаяся шляпа"] = "Glowing hat",
	["Конус из лучей над головой"] = "Cone of rays above the head",
	["Один блок, висит на шарнире"] = "One block on a hinge",
	["Цвет"] = "Color",
	["Цвет плаща"] = "Cape color",
	["Материал"] = "Material",
	["ЭФФЕКТЫ"] = "EFFECTS",
	["Бой"] = "Combat",
	["Тряска камеры"] = "Camera shake",
	["Реакция на получаемый урон"] = "Reacts to damage taken",
	["Смерть: молния"] = "Death: lightning",
	["Разрыв на частицы и молния"] = "Particle burst and lightning",
	["Смерть: распад"] = "Death: decay",
	["Рассыпается на частицы, без молнии"] = "Crumbles into particles, no lightning",
	["Цели смерти"] = "Death for",
	["Для кого играет"] = "Who it plays for",
	["Цель"] = "Target",
	["Таргет-эффект"] = "Target effect",
	["Аура на цели в прицеле"] = "Aura on the targeted player",
	["Инфо о цели"] = "Target info",
	["HP, ник и Display Name сверху"] = "HP, nick and Display Name on top",
	["Боты и Rig"] = "Bots and Rigs",
	["Таргет и на ботах с Humanoid"] = "Also targets Humanoid bots",
	["Зона таргета"] = "Target zone",
	["Настроить FOV прицела"] = "Set crosshair FOV",
	["Дистанция"] = "Distance",
	["Макс. дальность"] = "Max range",
	[" ст."] = " st.",
	["Стиль таргета"] = "Aura style",
	["Вид ауры"] = "Aura look",
	["МИР"] = "WORLD",
	["Погода и свет"] = "Weather & light",
	["Снег"] = "Snow",
	["Крупный снег по всей карте"] = "Big snowfall over the whole map",
	["Сила снега"] = "Snow level",
	["Плотность"] = "Density",
	["Светлячки"] = "Fireflies",
	["Мягкие огоньки вокруг игрока"] = "Soft glowing lights around you",
	["Время суток"] = "Time of day",
	["Фиксирует время"] = "Locks the time",
	["Туман"] = "Fog",
	["Пресеты и кастом"] = "Presets and custom",
	["Цвет тумана"] = "Fog color",
	["Для режима «Кастом.»"] = "For «Custom.» mode",
	["Сила тумана"] = "Fog power",
	["Поверхность"] = "Surface",
	["Следы шагов"] = "Footprints",
	["Светящиеся отпечатки на полу"] = "Glowing prints on the floor",
	["Волны при ходьбе"] = "Walk waves",
	["Круги от шагов, прыжка и падения"] = "Ripples from steps, jumps and landings",
	["Интервал волн"] = "Interval",
	["Секунды между"] = "Seconds between",
	["%.1f с"] = "%.1f s",
	["Дальность волн"] = "Range",
	["Радиус, студы"] = "Radius, studs",
	["ЭКРАН"] = "SCREEN",
	["Ватермарка"] = "Watermark",
	["Показывать FPS"] = "Show FPS",
	["Пинг"] = "Ping",
	["Показывать пинг"] = "Show ping",
	["Ник"] = "Nick",
	["Показывать ваш ник"] = "Show your nickname",
	["Тариф"] = "Plan",
	["Показывать тариф"] = "Show plan",
	["Размер"] = "Size",
	["Позиция X"] = "Position X",
	["Лево"] = "Left",
	["Центр"] = "Center",
	["Право"] = "Right",
	["Позиция Y"] = "Position Y",
	["Вверху"] = "Top",
	["Внизу"] = "Bottom",
	["Картинка"] = "Picture",
	["Свой FOV"] = "Custom FOV",
	["Включить управление FOV"] = "Enable FOV control",
	["Значение FOV"] = "FOV value",
	["Цветокоррекция"] = "Color grade",
	["Цвет тона"] = "Tint color",
	["Кино-свечение"] = "Cinematic glow",
	["Bloom и блюр на скорости"] = "Bloom and speed blur",
	["НАСТРОЙКИ"] = "SETTINGS",
	["Стиль"] = "Style",
	["Стиль меню"] = "Menu style",
	["Цвет интерфейса"] = "Interface color",
	["Цвет эффектов"] = "FX color",
	["Неон везде"] = "Neon everywhere",
	["Сила ауры"] = "Aura power",
	["Частицы и свечение"] = "Particles and glow",
	["Масштаб меню"] = "Menu scale",
	["Размер окна"] = "Window size",
	["Невозможно сменить масштаб на мобильном устройстве: доступно только 80%."] = "Cannot change the scale on a mobile device: only 80% is available.",
	["Система"] = "System",
	["Звуки"] = "Sounds",
	["Звуки интерфейса"] = "Interface sounds",
	["Ошибки видны всегда"] = "Errors are always shown",
	["Время показа"] = "Show time",
	["3 сек"] = "3 sec",
	["5 сек"] = "5 sec",
	["8 сек"] = "8 sec",
	["Размер увед."] = "Notif. size",
	["Увед.: X"] = "Notif.: X",
	["Позиция"] = "Position",
	["Так выглядят уведомления."] = "This is how notifications look.",
	["Увед.: Y"] = "Notif.: Y",
	["Защита от выброса за карту"] = "Protection from being flung off the map",
	["Тест уведомления"] = "Test notification",
	["Информационное окно"] = "Info popup",
	["Тест ошибки"] = "Test error",
	["Шаблон с кодом"] = "Template with code",
	["Тест тряски"] = "Test shake",
	["Тест молнии"] = "Test lightning",
	["Молния рядом с вами"] = "Lightning near you",
	["Тест распада"] = "Test decay",
	["Ваше тело рассыпется и вернётся"] = "Your body crumbles and returns",
	["Отключить всё"] = "Disable all",
	["Выключить визуальные модули"] = "Turn off visual modules",
	["Все визуальные модули выключены."] = "All visual modules disabled.",
	["Выгрузить скрипт"] = "Unload script",
	["Убрать NN-Project полностью"] = "Remove NN-Project completely",
	["   Назад"] = "   Back",
	["Версия "] = "Version ",
	["Разработчики"] = "Developers",
	["великий китаец DeepSeek"] = "the great Chinese DeepSeek",
	["Gemini (с деменцией)"] = "Gemini (with dementia)",
	["ВСЕ ПРАВА ЗАЩИЩЕНЫ ВЛАДЕЛЬЦЕМ vio.dev"] = "ALL RIGHTS RESERVED BY THE OWNER vio.dev",
	["О скрипте"] = "About",
	["Конфигов пока нет. Введите имя справа и нажмите «Сохранить»."] = "No configs yet. Enter a name on the right and press «Save».",
	["Да"] = "Yes",
	["Отмена"] = "Cancel",
	["Конфиги"] = "Configs",
	["Имя нового конфига"] = "New config name",
	["Сначала выберите конфиг в списке."] = "Select a config in the list first.",
	["Сохранить"] = "Save",
	["Конфиг «"] = "Config «",
	["» уже есть. Выберите его и нажмите «Переписать»."] = "» already exists. Select it and press «Overwrite».",
	["» сохранён."] = "» saved.",
	["Загрузить"] = "Load",
	["» загружен."] = "» loaded.",
	["Переписать"] = "Overwrite",
	["Переписать конфиг «"] = "Overwrite config «",
	["» текущими настройками?"] = "» with the current settings?",
	["» переписан."] = "» overwritten.",
	["Удалить"] = "Delete",
	["Удалить конфиг «"] = "Delete config «",
	["»? Это нельзя отменить."] = "»? This cannot be undone.",
	["» удалён."] = "» deleted.",
	["Файловая система недоступна: конфиги хранятся только до перезахода в игру."] = "File system unavailable: configs are kept only until you rejoin the game.",
	["Подождите, скрипт ещё загружается."] = "Please wait, the script is still loading.",
	["Загрузка"] = "Loading",
	["⛔ ВНИМАНИЕ"] = "⛔ WARNING",
	["ПРОЧИТАЙТЕ"] = "READ THIS",
	["Скрипт является всего лишь ClientSide-визуалом: он не является эксплойтом, а также fly/ESP/Aim-скриптом. Цель скрипта - всего лишь украсить ваш игровой процесс.\n\nПосле запуска вы подтверждаете, что берёте на себя ответственность за ваш аккаунт и его блокировку."] = "This script is only a ClientSide visual: it is not an exploit and not a fly/ESP/Aim script. Its only purpose is to decorate your gameplay.\n\nBy launching it, you confirm that you take full responsibility for your account and for any ban.",
	["Подтверждаю"] = "I agree",
	["Продолжить"] = "Continue",
	["Добро пожаловать в..."] = "Welcome to...",
	["Подождите"] = "Please wait",
	["Загружаем скрипт, это займет от 10 до 20 секунд. Проявите терпение пожалуйста."] = "Loading the script, this will take from 10 to 20 seconds. Please be patient.",
	["Скрипт загружен. Меню открывается кликом по ватермарке NN-Hub или клавишей RightShift."] = "Script loaded. Open the menu by clicking the NN-Hub watermark or pressing RightShift.",
	["Отключение..."] = "Disconnecting...",
	["До следующего запуска!"] = "See you next launch!",
	["Режим картошки"] = "Potato mode",
	["Убирает текстуры, только у вас"] = "Strips textures, only for you",
	["Дождь"] = "Rain",
	["Тихий быстрый дождь со звуком"] = "Quiet fast rain with sound",
	["Растяг экрана"] = "Stretch res",
	["Сжимает картинку по вертикали"] = "Squeezes the image vertically",
	["Значение"] = "Value",
	["Растяг: 0.50 - 1.00"] = "Stretch: 0.50 - 1.00",
	["Блюр"] = "Blur",
	["Сила на скорости"] = "Power at speed",
	["Свечение"] = "Glow",
	["Сила bloom"] = "Bloom power",
	["Вишня"] = "Cherry",
	["Черника"] = "Blueberry",
	["Голубика"] = "Bog bilberry",
	["Нежный красный"] = "Soft red",
	["Рой"] = "Swarm",
	["Трейл: от торса"] = "Trail: torso",
	["Плоская лента от торса"] = "Flat ribbon from torso",
	["Трейл: от ног"] = "Trail: feet",
	["Лента от ног, видна со всех сторон"] = "Feet ribbon, faces camera",
	["Длина"] = "Length",
	["Макс. длина, студы"] = "Max length, studs",
	["Время"] = "Lifetime",
	["Секунды жизни"] = "Seconds alive",
	["Ширина"] = "Width",
	["Студы"] = "Studs",
	["Орбиты"] = "Orbs",
	["Количество шаров"] = "Orb count",
	["КАМЕРА"] = "CAMERA",
	["Камера"] = "Camera",
	["Прицел"] = "Crosshair",
	["Отставание камеры"] = "Camera bounce",
	["Плавно, не от 1 лица"] = "Smooth, not in 1st person",
	["Сила"] = "Power",
	["Видно своё тело от 1 лица"] = "See your body in first person",
	["Крестик в стиле Minecraft"] = "Minecraft-style cross",
	["Рамка прицела"] = "Crosshair box",
	["Рамка на детали под прицелом"] = "Box on the part you aim at",
	["Рамка"] = "Box",
	["Альфа"] = "Alpha",
	["Прозрачность рамки"] = "Box transparency",
	["Квадрат прицела"] = "Crosshair square",
	["Квадрат парит над поверхностью"] = "Square floating above surface",
	["Квадрат"] = "Square",
	["Прозрачность квадрата"] = "Square transparency",
	["Проверка среды клиента"] = "Checking client environment",
	["Загрузка ассетов и звуков: "] = "Loading assets and sounds: ",
	["Проверяю цельность данных"] = "Verifying data integrity",
	["Успешно, загружаю скрипт"] = "Success, loading the script",
	["Всегда от 3 лица"] = "Always third person",
	["Работает в любой игре"] = "Works in any game",
	["Камера от 3 лица"] = "Third-person camera",
	["FOV этой функции"] = "FOV of this function",
	["С возвращением, "] = "Welcome back, ",
	["Вид и позиция"] = "Look & position",
	["Тесты"] = "Tests",
	["Звук смерти"] = "Death sound",
	["Закрыть"] = "Close",
	["Смещение камеры"] = "Camera offset",
	["Сдвиг камеры по X, Y и Z (не проходит сквозь стены)"] = "Shifts the camera along X, Y and Z (won't pass through walls)",
	["X · вправо"] = "X · right",
	["Y · вверх"] = "Y · up",
	["Z · вперёд"] = "Z · forward",
	["Сбросить камеру"] = "Reset camera",
	["Апельсин"] = "Orange",
	["Золото"] = "Gold",
	["Размер шляпы"] = "Hat size",
	["Высота шляпы"] = "Hat height",
	["Шляпа"] = "Hat",
	["Карточка цели"] = "Target card",
	["Показать превью"] = "Show preview",
	["Объединение двух стилей"] = "Merge two styles",
	["Показывать сразу два стиля ауры"] = "Show two aura styles at once",
	["Второй стиль"] = "Second style",
	["Вид второй ауры"] = "Look of the second aura",
	["HP + логи"] = "HP + logs",
	["Цель в прицеле"] = "Aimed target",
	["Только логи"] = "Logs only",
	["Что считать ударом"] = "What counts as a hit",
	["Радиус попадания"] = "Hit radius",
	["Макс. дистанция до цели"] = "Max distance to target",
	["Звук, когда у цели отнимается HP или по логам"] = "Plays when a target loses HP or by logs",
	["Звук при смерти игрока"] = "Plays a sound when a player dies",
	["Звук"] = "Sound",
	["Какой звук играет"] = "Which sound plays",
	["Громкость"] = "Volume",
	["Звук смерти (громкость)"] = "Death sound volume",
	["Проверить звук"] = "Preview sound",
	["Звук попадания"] = "Hit sound",
	["Звук, когда вы наносите урон"] = "Plays when you deal damage",
	["О скрипте"] = "About this script",
	["Скрипт загружен. Меню открывается кликом по ватермарке или клавишей RightShift."] = "Script loaded. Open the menu by clicking the watermark or pressing RightShift.",
}


--- Перевод строки интерфейса: в русском режиме возвращает оригинал
local function T(s)
	if Lang == "ENG" then
		return EN[s] or s
	end
	return s
end


-- ============================================================================
-- 1. КОНФИГУРАЦИЯ, СТИЛИ, ПРЕСЕТЫ
-- ============================================================================
local CONFIG = {
	ProjectName = "NN-Project",
	HubName = "NN-Hub",
	MenuTitle = "NoName-Project",   -- крупный заголовок в меню
	WatermarkTitle = "Visuals",    -- название в ватермарке
	Version = "1.0.2",
	Patch = "", -- у новой версии 2.x.x F-патча пока нет
	Generation = "Opus",
	Plan = "Free",                -- поле "тариф" в ватермарке
	ToggleKeys = { Enum.KeyCode.RightShift, Enum.KeyCode.Insert },
	OpenMenuOnStart = true,
	UseDisplayName = true,
	NotifyDuration = 5,
	MaxNotifications = 5,
	LowHpThreshold = 0.30,
	TargetRange = 150,            -- дальность таргет-эффекта (студы)
	AntiFlingSpeed = 280,         -- скорость (студ/с), выше которой импульс считается флингом
	AntiFlingSpin = 80,           -- угловая скорость, выше которой импульс считается флингом
	VignetteImageId = "",
	SnowTexture = "rbxasset://textures/particles/smoke_main.dds",
	RainTexture = "rbxasset://textures/particles/smoke_main.dds",
	RainSquash = -2,              -- вытягивание капель; если капли выглядят широкими, смените знак на 2
	DeathParticleTexture = "rbxassetid://102651850556408",
	ShowWarning = SHOW_WARNING,   -- окно "ВНИМАНИЕ" с выбором языка (см. раздел 0.1)
	ShowIntro = true,
	WarningCountdown = 6,         -- отсчёт после "Продолжить"
	IntroHold = 3,                -- сколько интро стоит после завершения анимации
	MinLoadTime = 10,             -- минимальное время "Загрузки" (текст уведомления: 10-20 сек)
	MaxLoadTime = 20,
	GuiName = "NNProject_Gui",
	FxFolderName = "NNProject_ClientFX",
}
CONFIG.BuildLabel = string.format("Build %s%s | %s", CONFIG.Version, CONFIG.Patch ~= "" and (" F" .. CONFIG.Patch) or "", CONFIG.Generation)

-- Звуки смерти игрока (функция "Звук смерти")
local DEATH_SOUNDS = {
	{ Name = "Agpa (1)", Id = 102651850556408 },
	{ Name = "Agpa (2)", Id = 104673402060812 },
	{ Name = "Rust Headshot", Id = 138750331387064 },
	{ Name = "Neverlose", Id = 139452805868562 },
	{ Name = "TF2 Headshot", Id = 138901307926331 },
	{ Name = "Skeet", Id = 140247876667835 },
}
-- Звуки попадания (функция "Звук попадания")
local HIT_SOUNDS = {
	{ Name = "Bubble", Id = 121434237134952 },
	{ Name = "OSU!", Id = 123941247147792 },
}

-- Что считать попаданием (функция "Звук попадания")
local HIT_MODES = { T("HP + логи"), T("Цель в прицеле"), T("Только логи") }

local SOUND_IDS = {
	Notify = 104673402060812,
	Error = 107294127858629,
	On = 8037925892,
	Off = 8037926758,
	Disintegrate = 102651850556408, -- теперь только прощание при выгрузке; из эффектов смерти убран
	Rain = 1516791621,
	Intro = 91896029011112,
}

-- Стили интерфейса: те же тёмные тона, что и у фиолетового, но с другим оттенком
local UI_SKINS = {
	{ Name = T("Зелёный"), Colors = {
		Background = Color3.fromRGB(22, 28, 24), Panel = Color3.fromRGB(30, 38, 33), Indicator = Color3.fromRGB(72, 92, 78),
		Stroke = Color3.fromRGB(44, 58, 48), Accent = Color3.fromRGB(72, 170, 100), AccentSoft = Color3.fromRGB(170, 255, 200),
		SwitchOn = Color3.fromRGB(80, 190, 115), SwitchOff = Color3.fromRGB(52, 66, 57), Pill = Color3.fromRGB(38, 50, 42),
		Muted = Color3.fromRGB(136, 150, 141) } },
	{ Name = T("Красный"), Colors = {
		Background = Color3.fromRGB(29, 22, 23), Panel = Color3.fromRGB(39, 30, 31), Indicator = Color3.fromRGB(95, 72, 74),
		Stroke = Color3.fromRGB(60, 44, 46), Accent = Color3.fromRGB(190, 70, 80), AccentSoft = Color3.fromRGB(255, 175, 180),
		SwitchOn = Color3.fromRGB(215, 85, 95), SwitchOff = Color3.fromRGB(68, 52, 54), Pill = Color3.fromRGB(52, 38, 40),
		Muted = Color3.fromRGB(150, 138, 140) } },
	{ Name = T("Серый"), Colors = {
		Background = Color3.fromRGB(25, 25, 27), Panel = Color3.fromRGB(35, 35, 38), Indicator = Color3.fromRGB(85, 85, 92),
		Stroke = Color3.fromRGB(52, 52, 58), Accent = Color3.fromRGB(150, 150, 165), AccentSoft = Color3.fromRGB(215, 215, 230),
		SwitchOn = Color3.fromRGB(160, 160, 180), SwitchOff = Color3.fromRGB(62, 62, 68), Pill = Color3.fromRGB(46, 46, 52),
		Muted = Color3.fromRGB(140, 140, 148) } },
	{ Name = T("Синий"), Colors = {
		Background = Color3.fromRGB(22, 25, 31), Panel = Color3.fromRGB(30, 35, 45), Indicator = Color3.fromRGB(70, 82, 110),
		Stroke = Color3.fromRGB(44, 52, 70), Accent = Color3.fromRGB(70, 110, 200), AccentSoft = Color3.fromRGB(170, 200, 255),
		SwitchOn = Color3.fromRGB(85, 125, 225), SwitchOff = Color3.fromRGB(52, 60, 80), Pill = Color3.fromRGB(38, 45, 60),
		Muted = Color3.fromRGB(136, 142, 155) } },
	{ Name = T("Фиолетовый"), Colors = {
		Background = Color3.fromRGB(28, 22, 36), Panel = Color3.fromRGB(47, 37, 53), Indicator = Color3.fromRGB(92, 76, 104),
		Stroke = Color3.fromRGB(58, 46, 66), Accent = Color3.fromRGB(122, 86, 168), AccentSoft = Color3.fromRGB(196, 172, 232),
		SwitchOn = Color3.fromRGB(125, 95, 215), SwitchOff = Color3.fromRGB(64, 52, 72), Pill = Color3.fromRGB(54, 43, 62),
		Muted = Color3.fromRGB(168, 150, 192) } },
	{ Name = T("Розовый"), Colors = {
		Background = Color3.fromRGB(30, 23, 28), Panel = Color3.fromRGB(41, 31, 38), Indicator = Color3.fromRGB(100, 72, 90),
		Stroke = Color3.fromRGB(62, 44, 56), Accent = Color3.fromRGB(205, 85, 160), AccentSoft = Color3.fromRGB(255, 180, 225),
		SwitchOn = Color3.fromRGB(225, 100, 175), SwitchOff = Color3.fromRGB(72, 52, 64), Pill = Color3.fromRGB(54, 40, 50),
		Muted = Color3.fromRGB(152, 138, 148) } },
	{ Name = T("Голубой"), Colors = {
		Background = Color3.fromRGB(22, 28, 31), Panel = Color3.fromRGB(30, 39, 44), Indicator = Color3.fromRGB(70, 95, 105),
		Stroke = Color3.fromRGB(44, 60, 68), Accent = Color3.fromRGB(60, 170, 195), AccentSoft = Color3.fromRGB(175, 235, 255),
		SwitchOn = Color3.fromRGB(70, 185, 215), SwitchOff = Color3.fromRGB(52, 68, 76), Pill = Color3.fromRGB(38, 52, 58),
		Muted = Color3.fromRGB(136, 148, 152) } },
}

local THEME = {
	Text = Color3.fromRGB(255, 255, 255),
	Error = Color3.fromRGB(235, 84, 96),
	Knob = Color3.fromRGB(238, 236, 244),
}
for key, color in pairs(UI_SKINS[5].Colors) do
	THEME[key] = color
end

-- Производные цвета "стекла" (пилюли меню, ватермарка): считаются из текущего стиля
local function DeriveTheme()
	THEME.Glass = THEME.Pill:Lerp(THEME.Background, 0.45)
	THEME.GlassOn = THEME.Glass:Lerp(THEME.SwitchOn, 0.55)
	THEME.GlassDeep = THEME.Glass:Lerp(Color3.new(0, 0, 0), 0.35)
	THEME.GlassHover = THEME.Glass:Lerp(Color3.new(1, 1, 1), 0.09)
end
DeriveTheme()

local TI = {
	Fast = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Medium = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Slow = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
	Expo = TweenInfo.new(0.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	In = TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.In),
	Back = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

local ERR = { ENABLE = "NN-E101", DISABLE = "NN-E102", TEST = "NN-E900" }

local AURA_LEVELS = {
	{ Name = T("Низкая"), Rate = 0.6, Glow = 5.5 },
	{ Name = T("Средняя"), Rate = 1.0, Glow = 7.0 },
	{ Name = T("Высокая"), Rate = 1.8, Glow = 9.0 },
}
local UI_SCALES = { 0.8, 1.0, 1.2 }
local NOTIFY_DURATIONS = { 3, 5, 8 }
local GEAR_COLORS = {
	{ Name = T("Фиолетовый"), Color = Color3.fromRGB(150, 90, 255) },
	{ Name = T("Синий"), Color = Color3.fromRGB(60, 120, 255) },
	{ Name = T("Красный"), Color = Color3.fromRGB(255, 60, 70) },
	{ Name = T("Зелёный"), Color = Color3.fromRGB(60, 230, 120) },
	{ Name = T("Белый"), Color = Color3.fromRGB(245, 245, 255) },
	{ Name = T("Чёрный"), Color = Color3.fromRGB(22, 22, 28) },
	{ Name = T("Золотой"), Color = Color3.fromRGB(255, 195, 60) },
	{ Name = T("Розовый"), Color = Color3.fromRGB(255, 100, 200) },
}
local CAPE_MATERIALS = {
	{ Name = "Neon", Material = Enum.Material.Neon },
	{ Name = "Forcefield", Material = Enum.Material.ForceField },
	{ Name = "Glass", Material = Enum.Material.Glass },
}
local SNOW_LEVELS = {
	{ Name = T("Лёгкий"), Rate = 120 },
	{ Name = T("Средний"), Rate = 260 },
	{ Name = T("Сильный"), Rate = 480 },
}
local TIME_PRESETS = {
	{ Name = T("Игровое") },
	{ Name = T("Рассвет"), Clock = 6.2 },
	{ Name = T("День"), Clock = 14 },
	{ Name = T("Закат"), Clock = 18.3 },
	{ Name = T("Ночь"), Clock = 0 },
}
local FOG_MODES = {
	{ Name = T("Игровой") },
	{ Name = T("Выкл"), Start = 900000, End = 1000000, Density = 0, Haze = 0, Color = Color3.fromRGB(190, 186, 210) },
	{ Name = T("Лёгкий"), Start = 40, End = 900, Density = 0.22, Haze = 0.9, Color = Color3.fromRGB(176, 172, 200) },
	{ Name = T("Густой"), Start = 0, End = 260, Density = 0.5, Haze = 2.4, Color = Color3.fromRGB(150, 146, 175) },
	{ Name = T("Кастом."), Custom = true, Start = 30, End = 700, Density = 0.3, Haze = 1.2 },
}
local GRADES = {
	{ Name = T("Нет") },
	{ Name = T("Кино"), Contrast = 0.18, Saturation = 0.2, Brightness = 0.01, Tint = Color3.fromRGB(255, 246, 236) },
	{ Name = T("Холодная"), Contrast = 0.12, Saturation = 0.05, Brightness = 0, Tint = Color3.fromRGB(200, 225, 255) },
	{ Name = T("Тёплая"), Contrast = 0.1, Saturation = 0.15, Brightness = 0.02, Tint = Color3.fromRGB(255, 225, 190) },
	{ Name = T("Ч/Б"), Contrast = 0.2, Saturation = -1, Brightness = 0, Tint = Color3.fromRGB(255, 255, 255) },
	{ Name = T("Яркая"), Contrast = 0.15, Saturation = 0.5, Brightness = 0.03, Tint = Color3.fromRGB(255, 255, 255) },
	{ Name = T("Мрачная"), Contrast = 0.25, Saturation = -0.35, Brightness = -0.06, Tint = Color3.fromRGB(210, 205, 225) },
	{ Name = T("Кастом."), Custom = true, Contrast = 0.12, Saturation = 0.1, Brightness = 0 },
}
local TARGET_STYLES = { "Constellation", "Helix", "Ghost Trail", "Ring", "Orbital Cube", "Orbital", "Swarm" }
local DEATH_TARGETS = { T("Все"), T("Только я"), T("Только другие") }

-- Пользовательские настройки (индексы в списках выше)
local Settings = {
	AuraLevel = 2, UiScale = 2, NotifyDurationIndex = 2, UiSkin = 5,
	GearColor = 1, CapeMaterial = 1,
	SnowLevel = 2, Time = 1, Fog = 1, Grade = 1, TargetStyle = 6, TargetStyle2 = 4, DeathTargets = 1,
	Fov = 70, WaveInterval = 4, WaveRange = 7,
	FogColor = Color3.fromRGB(176, 172, 200), GradeTint = Color3.fromRGB(255, 240, 230),
	FogStrength = 45,
	WmScale = 75, NotifyScale = 100, WmH = 2, WmV = 1, NotifyH = 3, NotifyV = 2,
	TargetFov = 12, TargetRange = 150,
	StretchRes = 0.75, BlurPower = 45, GlowPower = 38,
	FireflyColor = Color3.fromRGB(200, 255, 120), FireflySize = 50,
	TrailLength = 25, TrailLife = 8, TrailWidth = 12, OrbitCount = 6, CamBounce = 40,
	BoxSize = 100, BoxAlpha = 45, CrosshairSize = 100,
	ThirdDistance = 10, ThirdFov = 70,
	DeathSound = 1, DeathVolume = 80, HitSound = 1, HitVolume = 70, HitMode = 1, HitRange = 120,
	CamX = 0, CamY = 0, CamZ = 0, -- смещение камеры в десятых долях студа
	HatSize = 100, HatHeight = 0, -- размер шляпы в %, высота в десятых долях студа
	TargetInfoX = 100, TargetInfoY = 24, TargetInfoScale = 100, -- X и Y в половинках процента экрана (200 = 100%)
}


-- ============================================================================
-- 2. УТИЛИТЫ
-- ============================================================================
local NSK = NumberSequenceKeypoint.new
local NS = NumberSequence.new

--- Создаёт Instance, выставляет свойства, добавляет детей. Parent ставится последним.
local function Create(className, props, children)
	local inst = Instance.new(className)
	local parent = nil
	for key, value in pairs(props or {}) do
		if key == "Parent" then
			parent = value
		else
			inst[key] = value
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function Corner(radius)
	return Create("UICorner", { CornerRadius = radius })
end

local function Tween(inst, info, goal)
	local tw = TweenService:Create(inst, info, goal)
	tw:Play()
	return tw
end

local function Lerp(a, b, t)
	return a + (b - a) * t
end

--- Независимое от FPS экспоненциальное сглаживание: value += (target - value) * ExpAlpha(k, dt)
local function ExpAlpha(speed, dt)
	return 1 - math.exp(-speed * dt)
end

--- Надёжный тап: срабатывает при отпускании без заметного сдвига (Activated на телефоне иногда теряется)
local function OnTap(obj, callback)
	obj.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end
		local startPos = input.Position
		local moved = false
		local conn
		conn = input.Changed:Connect(function()
			if (input.Position - startPos).Magnitude > 14 then
				moved = true
			end
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				if not moved then
					callback()
				end
			end
		end)
	end)
end

--- Maid: собирает соединения, Instance, функции и вложенные Maid и чистит всё разом.
local Maid = {}
Maid.__index = Maid

function Maid.new()
	return setmetatable({ _items = {} }, Maid)
end

function Maid:Give(item)
	self._items[#self._items + 1] = item
	return item
end

function Maid:Clean()
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local item = items[i]
		local kind = typeof(item)
		if kind == "RBXScriptConnection" then
			item:Disconnect()
		elseif kind == "Instance" then
			if item:IsA("TweenBase") then
				item:Cancel()
			end
			item:Destroy()
		elseif kind == "function" then
			pcall(item)
		elseif kind == "thread" then
			pcall(task.cancel, item)
		elseif kind == "table" then
			if type(item.Clean) == "function" then
				item:Clean()
			elseif type(item.Destroy) == "function" then
				item:Destroy()
			end
		end
	end
end
Maid.Destroy = Maid.Clean

local Root = Maid.new() -- глобальная очистка при выгрузке

-- Хелперы персонажа
local function GetHumanoid(char)
	char = char or LocalPlayer.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetRoot(char)
	char = char or LocalPlayer.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetCamera()
	return Workspace.CurrentCamera
end

-- Папка для всех клиентских 3D-эффектов
local OldFx = Workspace:FindFirstChild(CONFIG.FxFolderName)
if OldFx then
	OldFx:Destroy()
end
local FxFolder = Create("Folder", { Name = CONFIG.FxFolderName, Parent = Workspace })

-- Общие параметры луча (обновляются перед каждым вызовом)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

--- Raycast, игнорирующий своего персонажа и папку эффектов.
--- respectCollide = true: пропускает детали с CanCollide = false (удобно для пола).
local function Raycast(origin, direction, character, respectCollide)
	local list = { FxFolder }
	if character then
		list[2] = character
	end
	rayParams.FilterDescendantsInstances = list
	rayParams.RespectCanCollide = respectCollide == true
	return Workspace:Raycast(origin, direction, rayParams)
end

--- Привязывает билдер к персонажу: вызывается сейчас и при каждом респавне.
--- builder(char, charMaid, isAlive): charMaid чистится при смерти/респавне/выключении.
--- isAlive() нужно проверять после любых WaitForChild.
local function BindCharacter(parentMaid, builder)
	local charMaid = Maid.new()
	parentMaid:Give(charMaid)
	local generation = 0

	local function attach(char)
		generation += 1
		local mine = generation
		charMaid:Clean()
		task.spawn(function()
			local ok, err = pcall(builder, char, charMaid, function()
				return mine == generation and char.Parent ~= nil
			end)
			if not ok then
				warn(T("[NN-Project] Ошибка в модуле: ") .. tostring(err))
			end
		end)
	end

	if LocalPlayer.Character then
		attach(LocalPlayer.Character)
	end
	parentMaid:Give(LocalPlayer.CharacterAdded:Connect(attach))
	parentMaid:Give(LocalPlayer.CharacterRemoving:Connect(function()
		generation += 1
		charMaid:Clean()
	end))
	-- Поднимается первым при очистке: отменяет билдеры, которые ещё ждут WaitForChild
	parentMaid:Give(function()
		generation += 1
	end)
end


-- ============================================================================
-- 3. ПАЛИТРА НЕОНА (цвета эффектов, не зависит от стиля интерфейса)
-- ============================================================================
local Palette = {
	Index = 1,
	Changed = Instance.new("BindableEvent"),
	Schemes = {
		{ Name = T("Неон-фиолет"), A = Color3.fromRGB(150, 90, 255), B = Color3.fromRGB(235, 110, 255) },
		{ Name = T("Мята"), A = Color3.fromRGB(80, 255, 200), B = Color3.fromRGB(80, 160, 255) },
		{ Name = T("Закат"), A = Color3.fromRGB(255, 140, 80), B = Color3.fromRGB(255, 60, 150) },
		{ Name = T("Лайм"), A = Color3.fromRGB(190, 255, 70), B = Color3.fromRGB(60, 230, 140) },
		{ Name = T("Радуга"), Rainbow = true, A = Color3.fromRGB(255, 80, 80), B = Color3.fromRGB(80, 80, 255) },
	{ Name = T("Белый"), A = Color3.fromRGB(255, 255, 255), B = Color3.fromRGB(205, 215, 240) },
	{ Name = T("Вишня"), A = Color3.fromRGB(135, 22, 50), B = Color3.fromRGB(205, 55, 85) },
	{ Name = T("Черника"), A = Color3.fromRGB(28, 42, 125), B = Color3.fromRGB(70, 100, 210) },
	{ Name = T("Голубика"), A = Color3.fromRGB(130, 190, 255), B = Color3.fromRGB(195, 228, 255) },
	{ Name = T("Нежный красный"), A = Color3.fromRGB(255, 125, 125), B = Color3.fromRGB(255, 180, 175) },
	{ Name = T("Апельсин"), A = Color3.fromRGB(255, 115, 0), B = Color3.fromRGB(255, 175, 45) },
	{ Name = T("Золото"), A = Color3.fromRGB(255, 196, 40), B = Color3.fromRGB(255, 228, 125) },
	},
}

function Palette.Current()
	return Palette.Schemes[Palette.Index]
end

function Palette.IsRainbow()
	return Palette.Current().Rainbow == true
end

function Palette.GetColors()
	local scheme = Palette.Current()
	if scheme.Rainbow then
		local t = os.clock() * 0.15
		return Color3.fromHSV(t % 1, 0.75, 1), Color3.fromHSV((t + 0.3) % 1, 0.75, 1)
	end
	return scheme.A, scheme.B
end

function Palette.Sequence()
	local scheme = Palette.Current()
	if scheme.Rainbow then
		local t = os.clock() * 0.15
		local keys = {}
		for i = 0, 4 do
			keys[#keys + 1] = ColorSequenceKeypoint.new(i / 4, Color3.fromHSV((t + i * 0.2) % 1, 0.75, 1))
		end
		return ColorSequence.new(keys)
	end
	return ColorSequence.new(scheme.A, scheme.B)
end

-- ============================================================================
-- 3.1 СТИЛИ ИНТЕРФЕЙСА (Skin): привязка свойств к ключам темы + плавная смена
-- ============================================================================
local Skin = { Index = Settings.UiSkin, _bound = {}, _refreshers = {} }

function Skin.Bind(inst, prop, key)
	inst[prop] = THEME[key]
	Skin._bound[#Skin._bound + 1] = { inst, prop, key }
	return inst
end

function Skin.OnChange(fn)
	Skin._refreshers[#Skin._refreshers + 1] = fn
end

function Skin.Apply(index, instant)
	Skin.Index = index
	for key, color in pairs(UI_SKINS[index].Colors) do
		THEME[key] = color
	end
	DeriveTheme()
	local alive = {}
	for _, entry in ipairs(Skin._bound) do
		local inst = entry[1]
		if inst.Parent ~= nil then
			alive[#alive + 1] = entry
			if instant then
				inst[entry[2]] = THEME[entry[3]]
			else
				Tween(inst, TI.Medium, { [entry[2]] = THEME[entry[3]] })
			end
		end
	end
	Skin._bound = alive
	for _, fn in ipairs(Skin._refreshers) do
		pcall(fn)
	end
end

--- Create + автопривязка: props.Skin = { СвойствоЦвета = "КлючТемы" }
local function Make(className, props, children)
	props = props or {}
	local skinMap = props.Skin
	props.Skin = nil
	local inst = Create(className, props, children)
	if skinMap then
		for prop, key in pairs(skinMap) do
			Skin.Bind(inst, prop, key)
		end
	end
	return inst
end

local function ColorToHex(c)
	return string.format("#%02x%02x%02x", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function HexToColor(text)
	text = (tostring(text):gsub("#", ""):gsub("%s", ""))
	if #text == 3 then
		text = text:gsub(".", "%0%0")
	end
	if #text ~= 6 or not text:match("^%x+$") then
		return nil
	end
	return Color3.fromRGB(tonumber(text:sub(1, 2), 16), tonumber(text:sub(3, 4), 16), tonumber(text:sub(5, 6), 16))
end

-- ============================================================================
-- 4. КОРНЕВОЙ ИНТЕРФЕЙС И РЕЕСТРЫ
-- ============================================================================
local OldGui = PlayerGui:FindFirstChild(CONFIG.GuiName)
if OldGui then
	OldGui:Destroy()
end

local ScreenGui = Create("ScreenGui", {
	Name = CONFIG.GuiName,
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

-- Остатки эффектов Lighting от прошлого запуска
for _, child in ipairs(Lighting:GetChildren()) do
	if string.sub(child.Name, 1, 3) == "NN_" then
		child:Destroy()
	end
end

local Features = {} -- id -> { Id, Name, Section, Enabled, UI }
local Modules = {}  -- id -> { Enable, Disable, ... }

local function IsEnabled(id)
	local feature = Features[id]
	return feature ~= nil and feature.Enabled == true
end

local function RegisterFeature(id, name, section)
	Features[id] = Features[id] or { Id = id, Name = name, Section = section, Enabled = false }
	return Features[id]
end

--- Камера в первом лице: она находится практически в голове персонажа
local function IsFirstPerson()
	local cam = GetCamera()
	if not cam then
		return false
	end
	if LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
		return true
	end
	-- зум стандартной камеры: в первом лице расстояние камера - фокус около 0.5 и не прыгает при поворотах
	return (cam.Focus.Position - cam.CFrame.Position).Magnitude < 0.9
end

--- ShiftLock: курсор заблокирован по центру экрана
local function IsLockedCenter()
	return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

--- От первого лица вся косметика (кроме волн) временно отключается, чтобы не было визуальных багов
local Cosmetics = {
	Hidden = false,
	Suspended = {},
	Ids = { Aura = true, OrbitAura = true, GlowHat = true, Cape = true, TrailTorso = true, TrailFeet = true, FootTrails = true },
}

function Cosmetics.Update(fp)
	if fp == Cosmetics.Hidden then
		return
	end
	Cosmetics.Hidden = fp
	if fp then
		for id in pairs(Cosmetics.Ids) do
			if IsEnabled(id) and not Cosmetics.Suspended[id] then
				Cosmetics.Suspended[id] = true
				pcall(Modules[id].Disable)
			end
		end
	else
		for id in pairs(Cosmetics.Suspended) do
			Cosmetics.Suspended[id] = nil
			if IsEnabled(id) then
				pcall(Modules[id].Enable)
			end
		end
	end
end

local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if IsMobile then
	Settings.UiScale = 1 -- на телефоне доступен только масштаб 80%
end
Settings.NotifyV = IsMobile and 1 or 2 -- по умолчанию: телефон - сверху, ПК - снизу
Settings.TargetFov = IsMobile and 20 or 12

-- ============================================================================
-- 4.1 ЗВУКИ ИНТЕРФЕЙСА
-- ============================================================================
local Sfx = { Enabled = true }

function Sfx.Play(name, volume, lifetime)
	if not Sfx.Enabled then
		return nil
	end
	local id = SOUND_IDS[name]
	if not id then
		return nil
	end
	local sound = Create("Sound", {
		Name = "NN_" .. name,
		SoundId = "rbxassetid://" .. tostring(id),
		Volume = volume or 0.6,
		Parent = SoundService,
	})
	sound:Play()
	Debris:AddItem(sound, lifetime or 8)
	return sound
end

--- Звук фиксированной длительности с плавным входом и затуханием.
function Sfx.PlayTimed(name, volume, seconds, fadeIn, fadeOut)
	local sound = Sfx.Play(name, 0, seconds + 1)
	if not sound then
		return nil
	end
	volume = volume or 0.7
	fadeIn = fadeIn or 0.05
	fadeOut = fadeOut or 0.2
	Tween(sound, TweenInfo.new(fadeIn, Enum.EasingStyle.Linear), { Volume = volume })
	task.delay(math.max(seconds - fadeOut, 0), function()
		if sound.Parent then
			Tween(sound, TweenInfo.new(fadeOut, Enum.EasingStyle.Linear), { Volume = 0 })
		end
	end)
	task.delay(seconds, function()
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end)
	return sound
end

--- Одиночный звук по id (звуки смерти и попадания). Не зависит от переключателя "Звуки": у них свои функции.
local function PlayAsset(id, volume, lifetime)
	local sound = Create("Sound", {
		Name = "NN_Fx", SoundId = "rbxassetid://" .. tostring(id), Volume = math.clamp(volume, 0, 2), Parent = SoundService,
	})
	sound:Play()
	Debris:AddItem(sound, lifetime or 8)
	return sound
end

-- ============================================================================
-- 5. СИСТЕМА УВЕДОМЛЕНИЙ
-- ============================================================================
local Notify = { Enabled = true }
local NOTIFY_WIDTH = IsMobile and 280 or 340

local NotifyHolder = Create("Frame", {
	Name = "Notifications", BackgroundTransparency = 1, Size = UDim2.new(0, NOTIFY_WIDTH + 28, 1, 0), Parent = ScreenGui,
}, {
	Create("UIScale", { Name = "Scale" }),
	Create("UIPadding", {
		Name = "Pad", PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14),
		PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
	}),
	Create("UIListLayout", {
		Name = "List", FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10),
	}),
})

--- Положение (лево / центр / право + вверху / внизу) и размер уведомлений
function Notify.Relayout()
	local h = ({ 0, 0.5, 1 })[Settings.NotifyH]
	local top = Settings.NotifyV == 1
	local s = Settings.NotifyScale / 100
	NotifyHolder.AnchorPoint = Vector2.new(h, top and 0 or 1)
	NotifyHolder.Position = UDim2.fromScale(h, top and 0 or 1)
	NotifyHolder.Scale.Scale = s
	NotifyHolder.Size = UDim2.new(0, NOTIFY_WIDTH + 28, 1 / s, 0)
	NotifyHolder.List.VerticalAlignment = top and Enum.VerticalAlignment.Top or Enum.VerticalAlignment.Bottom
	NotifyHolder.Pad.PaddingTop = UDim.new(0, top and 56 or 14) -- сверху оставляем место под панель Roblox
end
Notify.Relayout()

local notifyCounter = 0
local activeNotifications = {}

--- opts: Kind ("info"/"error"), Title, Subtitle, Body, Code, Duration (nil = пока не закроют), NoSound
local function BuildNotification(opts)
	notifyCounter += 1
	local isError = opts.Kind == "error"
	local titleText = opts.Title or (isError and T("Ошибка") or T("Уведомления"))
	local offscreenX = (NOTIFY_WIDTH + 60) * (Settings.NotifyH == 1 and -1 or 1) -- въезжает со стороны своего края
	local timed = opts.Duration ~= nil

	local wrapper = Create("Frame", {
		Name = "Notify_" .. notifyCounter,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = notifyCounter,
		Parent = NotifyHolder,
	})

	local card = Make("CanvasGroup", {
		Name = "Card",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(offscreenX, 0),
		GroupTransparency = 1,
		Skin = { BackgroundColor3 = "Background" },
		Parent = wrapper,
	}, {
		Corner(UDim.new(0, 18)),
		Make("UIStroke", { Thickness = 1, Transparency = 0.75, Color = THEME.Error, Skin = (not isError) and { Color = "AccentSoft" } or nil }),
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18),
		}),
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 3) }),
	})

	local function textLabel(props, skinMap)
		local base = {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextWrapped = true,
			Skin = skinMap,
			Parent = card,
		}
		for key, value in pairs(props) do
			base[key] = value
		end
		return Make("TextLabel", base)
	end

	textLabel({ Name = "Title", LayoutOrder = 1, Font = Enum.Font.GothamBold, TextSize = 21, TextColor3 = THEME.Text, Text = titleText })
	textLabel({ Name = "Subtitle", LayoutOrder = 2, Font = Enum.Font.Gotham, TextSize = 13, Text = opts.Subtitle or "" }, { TextColor3 = "Muted" })
	local bodyLabel = textLabel({ Name = "Body", LayoutOrder = 3, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = THEME.Text, Text = opts.Body or "" })
	Create("UIPadding", { PaddingTop = UDim.new(0, 8), Parent = bodyLabel })

	if opts.Code then
		local footer = textLabel({ Name = "Footer", LayoutOrder = 4, Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = THEME.Error, Text = T("Код ошибки: ") .. tostring(opts.Code) })
		Create("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = footer })
	end

	Create("Frame", { Name = "Spacer", LayoutOrder = 5, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8), Parent = card })
	local track = Make("Frame", {
		Name = "Progress", LayoutOrder = 6, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 3),
		Skin = { BackgroundColor3 = "Panel" }, Parent = card,
	}, { Corner(UDim.new(1, 0)) })
	local fill = Make("Frame", {
		Name = "Fill", BorderSizePixel = 0, Size = timed and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 1),
		BackgroundColor3 = THEME.Error, Skin = (not isError) and { BackgroundColor3 = "AccentSoft" } or nil, Parent = track,
	}, { Corner(UDim.new(1, 0)) })

	local handle = {}
	local closed = false

	local function dismiss()
		if closed then
			return
		end
		closed = true
		for i, entry in ipairs(activeNotifications) do
			if entry == handle then
				table.remove(activeNotifications, i)
				break
			end
		end
		task.spawn(function()
			if not card.Parent then
				return
			end
			local out = Tween(card, TI.In, { Position = UDim2.fromOffset(offscreenX, 0), GroupTransparency = 1 })
			out.Completed:Wait()
			if not wrapper.Parent then
				return
			end
			local height = wrapper.AbsoluteSize.Y
			wrapper.AutomaticSize = Enum.AutomaticSize.None
			wrapper.Size = UDim2.new(1, 0, 0, height)
			local collapse = Tween(wrapper, TI.Fast, { Size = UDim2.new(1, 0, 0, 0) })
			collapse.Completed:Wait()
			wrapper:Destroy()
		end)
	end
	handle.Dismiss = dismiss
	function handle.SetProgress(alpha)
		if fill.Parent then
			Tween(fill, TI.Fast, { Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1) })
		end
	end
	function handle.SetBody(text)
		bodyLabel.Text = text
	end

	local clickArea = Create("TextButton", {
		Name = "Click", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = wrapper,
	})
	clickArea.Activated:Connect(dismiss)

	activeNotifications[#activeNotifications + 1] = handle
	while #activeNotifications > CONFIG.MaxNotifications do
		activeNotifications[1].Dismiss()
	end

	if not opts.NoSound then
		Sfx.Play(isError and "Error" or "Notify", 0.6)
	end
	Tween(card, TI.Medium, { Position = UDim2.fromOffset(0, 0), GroupTransparency = 0 })
	if timed then
		Tween(fill, TweenInfo.new(opts.Duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
		task.delay(opts.Duration, dismiss)
	end
	return handle
end

function Notify.Info(body, subtitle, duration, noSound)
	if not Notify.Enabled then
		return nil
	end
	return BuildNotification({ Kind = "info", Subtitle = subtitle or CONFIG.ProjectName, Body = body or "", Duration = duration or CONFIG.NotifyDuration, NoSound = noSound })
end

--- Уведомление со своим заголовком, описанием и текстом (показывается даже при выключенных уведомлениях)
function Notify.Custom(title, subtitle, body, duration)
	return BuildNotification({ Kind = "info", Title = title, Subtitle = subtitle, Body = body, Duration = duration or CONFIG.NotifyDuration })
end

function Notify.Error(body, code, subtitle, duration)
	return BuildNotification({ Kind = "error", Subtitle = subtitle or T("Описание сообщения"), Body = body or "", Code = code or ERR.TEST, Duration = duration or CONFIG.NotifyDuration })
end

--- Постоянное уведомление с прогресс-баром (закрывается через handle.Dismiss()).
function Notify.Loading(title, subtitle, body, noSound)
	return BuildNotification({ Kind = "info", Title = title, Subtitle = subtitle, Body = body, Duration = nil, NoSound = noSound })
end

-- ============================================================================
-- 6. ВАТЕРМАРКА (она же кнопка открытия меню). Название убрать нельзя.
-- Вид по референсу: тёмная пилюля, логотип NN, название, FPS и пинг.
-- ============================================================================
--- Логотип NN по референсу: две буквы N с общей средней стойкой (три стойки + две диагонали).
--- Все размеры считаются от высоты, поэтому логотип не растягивается и не ломается при масштабировании.
local function BuildLogo(parent, height, color)
	local h = height
	local w = math.floor(h * 0.79 + 0.5)               -- ширина одной буквы N
	local stem = math.max(2, math.floor(h * 0.17 + 0.5)) -- толщина стойки
	local step = w - stem                              -- смещение второй N (общая стойка)
	local logo = Create("Frame", {
		Name = "Logo", Size = UDim2.fromOffset(step * 2 + stem, h), BackgroundTransparency = 1, ClipsDescendants = true, Parent = parent,
	})
	for i = 0, 2 do
		Create("Frame", {
			Position = UDim2.fromOffset(i * step, 0), Size = UDim2.fromOffset(stem, h), BorderSizePixel = 0,
			BackgroundColor3 = color, Parent = logo,
		})
	end
	-- диагональ идёт из левого верхнего угла стойки в правый нижний угол следующей стойки
	local length = math.sqrt(step * step + h * h)
	local thickness = (stem * 1.08) * h / length
	local angle = -math.deg(math.atan2(step, h))
	for i = 0, 1 do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(i * step + w / 2, h / 2),
			Size = UDim2.fromOffset(thickness, length + 2), Rotation = angle, BorderSizePixel = 0,
			BackgroundColor3 = color, Parent = logo,
		})
	end
	return logo
end

local Watermark = {
	Visible = false,    -- ватермарка включена
	Suppressed = false, -- временно скрыта (пока открыто меню)
	Shown = false,      -- реально показана на экране
	Show = { Fps = true, Ping = true, Nick = true, Tariff = true },
}

do
	local frame = Make("CanvasGroup", {
		Name = "Watermark",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -50),
		Size = UDim2.new(0, 0, 0, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Skin = { BackgroundColor3 = "Glass" },
		Parent = ScreenGui,
	}, {
		Corner(UDim.new(1, 0)),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 20), PaddingRight = UDim.new(0, 22) }),
		Create("UIScale", { Name = "Scale" }),
	})
	local stroke = Make("UIStroke", { Thickness = 1, Transparency = 0.45, Skin = { Color = "Stroke" }, Parent = frame })

	local inner = Create("Frame", {
		Name = "Inner", BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, Parent = frame,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10),
		}),
	})
	local logoHolder = Create("Frame", { Name = "LogoHolder", LayoutOrder = 1, BackgroundTransparency = 1, Parent = inner })
	logoHolder.Size = BuildLogo(logoHolder, 24, Color3.fromRGB(246, 240, 255)).Size
	Create("TextLabel", {
		Name = "Title", LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = THEME.Text, Text = CONFIG.WatermarkTitle, Parent = inner,
	})
	local spacer = Create("Frame", { Name = "Spacer", LayoutOrder = 3, BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 1), Parent = inner })
	local stats = Create("TextLabel", {
		Name = "Stats", LayoutOrder = 4, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamMedium, TextSize = 16, TextColor3 = THEME.Text, Text = "", Parent = inner,
	})

	local button = Create("TextButton", {
		Name = "Click", BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(-20, 0), Size = UDim2.new(1, 42, 1, 0), ZIndex = 5, Parent = frame,
	})

	local displayName = CONFIG.UseDisplayName and LocalPlayer.DisplayName or LocalPlayer.Name
	local fps, ping = 60, 0

	local function readPing()
		local ok, value = pcall(function()
			return Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
		end)
		if ok and type(value) == "number" then
			return math.floor(value + 0.5)
		end
		local ok2, seconds = pcall(function()
			return LocalPlayer:GetNetworkPing()
		end)
		if ok2 and type(seconds) == "number" then
			return math.floor(seconds * 1000 + 0.5)
		end
		return 0
	end

	--- Название и логотип выводятся всегда - это кнопка меню; остальные поля по желанию.
	local function refresh()
		local parts = {}
		if Watermark.Show.Fps then
			parts[#parts + 1] = string.format("%dFPS", fps)
		end
		if Watermark.Show.Ping then
			parts[#parts + 1] = string.format("%dms", ping)
		end
		if Watermark.Show.Nick then
			parts[#parts + 1] = displayName
		end
		if Watermark.Show.Tariff then
			parts[#parts + 1] = CONFIG.Plan
		end
		stats.Text = table.concat(parts, "    ")
		spacer.Visible = #parts > 0
	end
	Watermark.Refresh = refresh
	Skin.OnChange(refresh)
	refresh()

	local frames, accum = 0, 0
	Root:Give(RunService.RenderStepped:Connect(function(dt)
		if not Watermark.Shown then
			frames, accum = 0, 0
			return
		end
		frames += 1
		accum += dt
		if accum >= 0.3 then
			fps = math.floor(frames / accum + 0.5)
			frames, accum = 0, 0
			ping = readPing()
			refresh()
		end
	end))

	button.MouseEnter:Connect(function()
		Tween(stroke, TI.Fast, { Color = THEME.AccentSoft, Transparency = 0 })
	end)
	button.MouseLeave:Connect(function()
		Tween(stroke, TI.Fast, { Color = THEME.Stroke, Transparency = 0.45 })
	end)
	OnTap(button, function()
		if Watermark.OnClick then
			Watermark.OnClick()
		end
	end)

	local function positions()
		local h = ({ 0, 0.5, 1 })[Settings.WmH]
		local top = Settings.WmV == 1
		local xOff = h == 0 and 14 or (h == 1 and -14 or 0)
		local shown = UDim2.new(h, xOff, top and 0 or 1, top and 12 or -12)
		local hidden = UDim2.new(h, xOff, top and 0 or 1, top and -60 or 60)
		return h, top, shown, hidden
	end

	--- Применяет размер и положение (лево/центр/право + вверху/внизу)
	function Watermark.Relayout(instant)
		local h, top, shown, hidden = positions()
		frame.AnchorPoint = Vector2.new(h, top and 0 or 1)
		frame.Scale.Scale = Settings.WmScale / 100
		if Watermark.Shown then
			if instant then
				frame.Position = shown
			else
				Tween(frame, TI.Medium, { Position = shown })
			end
		else
			frame.Position = hidden
		end
	end

	--- Показывает или прячет рамку с учётом двух флагов: "включена" и "временно скрыта"
	function Watermark.Present()
		local want = Watermark.Visible and not Watermark.Suppressed
		if want == Watermark.Shown then
			return
		end
		Watermark.Shown = want
		local h, top, shown, hidden = positions()
		frame.AnchorPoint = Vector2.new(h, top and 0 or 1)
		if want then
			frame.Visible = true
			ping = readPing()
			refresh()
			Tween(frame, TI.Slow, { Position = shown, GroupTransparency = 0 })
		else
			local tw = Tween(frame, TI.In, { Position = hidden, GroupTransparency = 1 })
			tw.Completed:Connect(function()
				if not Watermark.Shown then
					frame.Visible = false
				end
			end)
		end
	end

	function Watermark.SetVisible(state)
		Watermark.Visible = state
		Watermark.Present()
	end

	--- Пока открыто меню, ватермарка не нужна: закрыть меню можно кнопкой "Закрыть"
	function Watermark.Suppress(flag)
		Watermark.Suppressed = flag
		Watermark.Present()
	end
	Watermark.Relayout(true)
end

-- Подпись в левом нижнем углу: версия, поколение и случайный ID сессии (для вида), мелко и полупрозрачно
do
	local rng = Random.new(os.time() + math.floor(os.clock() * 1000))
	local digits = { tostring(rng:NextInteger(1, 9)) }
	for i = 2, 10 do
		digits[i] = tostring(rng:NextInteger(0, 9))
	end
	CONFIG.SessionId = table.concat(digits)
	Create("TextLabel", {
		Name = "VersionTag", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -6), Size = UDim2.fromOffset(0, 14),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 11,
		TextColor3 = Color3.new(1, 1, 1), TextTransparency = 0.55, TextXAlignment = Enum.TextXAlignment.Left,
		Text = string.format("V%s | %s | Your ID: %s", CONFIG.Version, CONFIG.Generation, CONFIG.SessionId), Parent = ScreenGui,
	})
end


-- ----------------------------------------------------------------------------
-- 8.11f Trail: нормальный след с настройками (длина, время жизни, ширина), режимы "от торса" / "от ног"
-- От торса: плоская лента. От ног: лента всегда повёрнута к камере (FaceCamera), без плоскости.
-- ----------------------------------------------------------------------------
local function makeTrailModule(mode)
	local M = {}
	local maid
	local live = {}

	local function apply(entry)
		entry.Trail.Lifetime = Settings.TrailLife * 0.1
		entry.Trail.MaxLength = Settings.TrailLength
		local half = Settings.TrailWidth * 0.05
		entry.A0.Position = entry.Base + Vector3.new(0, half, 0)
		entry.A1.Position = entry.Base - Vector3.new(0, half, 0)
	end

	function M.Refresh()
		for _, entry in ipairs(live) do
			if entry.Trail.Parent then
				apply(entry)
			end
		end
	end

	function M.Enable()
		maid = Maid.new()
		live = {}
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or not isAlive() then
				return
			end
			local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
			local targets = {}
			if mode == "torso" then
				local torso = char:WaitForChild(r15 and "UpperTorso" or "Torso", 5)
				if torso then
					targets[1] = { Part = root, Base = root.CFrame:PointToObjectSpace(torso.Position) }
				end
			else
				for _, name in ipairs(r15 and { "LeftFoot", "RightFoot" } or { "Left Leg", "Right Leg" }) do
					local part = char:WaitForChild(name, 5)
					if part then
						targets[#targets + 1] = { Part = root, Base = root.CFrame:PointToObjectSpace(part.Position) + Vector3.new(0, -part.Size.Y / 2 + 0.15, 0) }
					end
				end
			end
			if not isAlive() then
				return
			end

			local entries = {}
			for _, target in ipairs(targets) do
				local a0 = Create("Attachment", { Parent = target.Part })
				local a1 = Create("Attachment", { Parent = target.Part })
				local trail = Create("Trail", {
					Attachment0 = a0, Attachment1 = a1, MinLength = 0.05, FaceCamera = mode == "feet",
					LightEmission = 1, LightInfluence = 0, Enabled = false, Color = Palette.Sequence(),
					Transparency = NS({ NSK(0, 0.1), NSK(1, 1) }), WidthScale = NS({ NSK(0, 1), NSK(1, 0) }),
					Parent = target.Part,
				})
				local entry = { Trail = trail, A0 = a0, A1 = a1, Base = target.Base }
				apply(entry)
				cmaid:Give(trail)
				cmaid:Give(a0)
				cmaid:Give(a1)
				entries[#entries + 1] = entry
				live[#live + 1] = entry
			end

			local function applyColors()
				local sequence = Palette.Sequence()
				for _, entry in ipairs(entries) do
					entry.Trail.Color = sequence
				end
			end
			cmaid:Give(Palette.Changed.Event:Connect(applyColors))

			local smooth, colorTimer = 0, 0
			cmaid:Give(RunService.Heartbeat:Connect(function(dt)
				if not root.Parent then
					return
				end
				smooth += (root.AssemblyLinearVelocity.Magnitude - smooth) * ExpAlpha(10, dt)
				local moving = smooth > 3
				for _, entry in ipairs(entries) do
					if entry.Trail.Enabled ~= moving then
						entry.Trail.Enabled = moving
					end
				end
				if Palette.IsRainbow() then
					colorTimer += dt
					if colorTimer > 0.1 then
						colorTimer = 0
						applyColors()
					end
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		live = {}
	end

	return M
end

Modules.TrailTorso = makeTrailModule("torso")
Modules.TrailFeet = makeTrailModule("feet")

-- ----------------------------------------------------------------------------
-- 7.2 Aura: частицы вокруг тела + мягкое свечение, которое дышит и растёт со скоростью
-- ----------------------------------------------------------------------------
Modules.Aura = (function()
	local M = {}
	local maid

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not root or not isAlive() then
				return
			end
			local level = AURA_LEVELS[Settings.AuraLevel]

			-- Контейнеры-Attachment на трёх высотах тела; в каждом два эмиттера
			local emitterData = {}
			for _, height in ipairs({ -1.4, 0, 1.4 }) do
				local att = Create("Attachment", { Name = "NN_AuraContainer", Position = Vector3.new(0, height, 0), Parent = root })
				cmaid:Give(att)

				-- Лёгкие "мотыльки": медленно плывут вверх и тают
				local motes = Create("ParticleEmitter", {
					Name = "NN_Motes",
					Color = Palette.Sequence(),
					LightEmission = 1,
					LightInfluence = 0,
					Size = NS({ NSK(0, 0), NSK(0.2, 0.45), NSK(1, 0) }),
					Transparency = NS({ NSK(0, 1), NSK(0.15, 0.2), NSK(1, 1) }),
					Lifetime = NumberRange.new(1.2, 2.4),
					Rate = 6 * level.Rate,
					Speed = NumberRange.new(0.5, 2.5),
					SpreadAngle = Vector2.new(180, 180),
					Drag = 1.5,
					Acceleration = Vector3.new(0, 1.2, 0),
					Rotation = NumberRange.new(0, 360),
					RotSpeed = NumberRange.new(-60, 60),
					LockedToPart = false,
					Parent = att,
				})
				-- Редкие яркие искры, быстро взлетают
				local embers = Create("ParticleEmitter", {
					Name = "NN_Embers",
					Color = Palette.Sequence(),
					LightEmission = 1,
					LightInfluence = 0,
					Size = NS({ NSK(0, 0.25), NSK(1, 0) }),
					Transparency = NS({ NSK(0, 0), NSK(1, 1) }),
					Lifetime = NumberRange.new(0.6, 1.1),
					Rate = 2.5 * level.Rate,
					Speed = NumberRange.new(1, 3),
					SpreadAngle = Vector2.new(60, 60),
					Acceleration = Vector3.new(0, 5, 0),
					LockedToPart = false,
					Parent = att,
				})
				emitterData[#emitterData + 1] = { Emitter = motes, Base = 6 * level.Rate }
				emitterData[#emitterData + 1] = { Emitter = embers, Base = 2.5 * level.Rate }
			end

			-- Свечение: несколько вложенных полупрозрачных кругов дают мягкий радиальный градиент
			local glow = Create("BillboardGui", {
				Name = "NN_AuraGlow",
				Adornee = root,
				AlwaysOnTop = false,
				LightInfluence = 0,
				Size = UDim2.fromScale(level.Glow, level.Glow),
				Parent = root,
			})
			cmaid:Give(glow)
			local layers = {}
			for i, scale in ipairs({ 1, 0.82, 0.66, 0.52, 0.4, 0.3 }) do
				layers[i] = Create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(scale, scale),
					BackgroundTransparency = 0.94,
					BorderSizePixel = 0,
					Parent = glow,
				}, { Corner(UDim.new(1, 0)) })
			end

			local function applyColors()
				local A, B = Palette.GetColors()
				local sequence = Palette.Sequence()
				for _, data in ipairs(emitterData) do
					data.Emitter.Color = sequence
				end
				for i, layer in ipairs(layers) do
					layer.BackgroundColor3 = A:Lerp(B, (i - 1) / (#layers - 1))
				end
			end
			applyColors()
			cmaid:Give(Palette.Changed.Event:Connect(applyColors))

			local smooth, rateTimer = 0, 0
			cmaid:Give(RunService.Heartbeat:Connect(function(dt)
				if not root.Parent then
					return
				end
				local speed = root.AssemblyLinearVelocity.Magnitude
				smooth += (speed - smooth) * ExpAlpha(8, dt)

				-- Размер свечения = база * (1 + дыхание sin + прирост от скорости)
				local pulse = 1 + math.sin(os.clock() * 2.2) * 0.07 + math.clamp(smooth / 80, 0, 0.2)
				local size = level.Glow * pulse
				glow.Size = UDim2.fromScale(size, size)

				rateTimer += dt
				if rateTimer > 0.15 then
					rateTimer = 0
					local boost = 1 + math.clamp(smooth / 25, 0, 1.5) -- в движении частиц больше
					for _, data in ipairs(emitterData) do
						data.Emitter.Rate = data.Base * boost
					end
					if Palette.IsRainbow() then
						applyColors()
					end
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 7.3 FootTrails: светящиеся отпечатки на полу (пул деталей, без спама Instance)
-- ----------------------------------------------------------------------------
Modules.FootTrails = (function()
	local M = {}
	local maid
	local pool, all = {}, {}

	local function release(rec)
		if rec.Tween then
			rec.Tween:Cancel()
			rec.Tween = nil
		end
		rec.Part.Parent = nil
		pool[#pool + 1] = rec
	end

	local function newRecord()
		local part = Create("Part", {
			Name = "NN_Footprint",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Material = Enum.Material.Neon,
			Shape = Enum.PartType.Cylinder, -- ось цилиндра = X, поэтому ставим её вдоль нормали
			Size = Vector3.new(0.05, 1.3, 0.8),
			Transparency = 1,
		})
		local sparks = Create("ParticleEmitter", {
			Rate = 0,
			Lifetime = NumberRange.new(0.25, 0.5),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(35, 35),
			Acceleration = Vector3.new(0, -12, 0),
			Drag = 2,
			Size = NS({ NSK(0, 0.28), NSK(1, 0) }),
			Transparency = NS({ NSK(0, 0), NSK(1, 1) }),
			LightEmission = 1,
			LightInfluence = 0,
			EmissionDirection = Enum.NormalId.Right, -- локальная +X = нормаль поверхности
			Parent = part,
		})
		local rec = { Part = part, Sparks = sparks, Tween = nil }
		all[#all + 1] = rec
		return rec
	end

	--- Ставит отпечаток: forward лежит в плоскости поверхности, side = -1 (левая) / +1 (правая нога)
	local function place(position, normal, forward, side, big)
		local rec = table.remove(pool) or newRecord()
		if rec.Tween then
			rec.Tween:Cancel()
			rec.Tween = nil
		end
		local part = rec.Part
		local A, B = Palette.GetColors()
		local color = side > 0 and A or B
		local length = big and 1.7 or 1.25
		local width = big and 1.0 or 0.75

		local right = forward:Cross(normal)
		local center = position + right * side * 0.42 + normal * 0.04

		part.Size = Vector3.new(0.05, length, width)
		part.CFrame = CFrame.fromMatrix(center, normal, forward) -- X = нормаль, Y = направление шага
		part.Color = color
		part.Transparency = 0.2
		part.Parent = FxFolder
		rec.Sparks.Color = ColorSequence.new(color)
		rec.Sparks:Emit(big and 6 or 3)

		local tw = TweenService:Create(part, TweenInfo.new(big and 1.6 or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
			Size = Vector3.new(0.05, length * 0.55, width * 0.55),
		})
		rec.Tween = tw
		tw.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed and rec.Tween == tw then
				release(rec)
			end
		end)
		tw:Play()
	end

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or not isAlive() then
				return
			end

			local lastPos = root.Position
			local travelled = 0 -- пройденная по земле дистанция с прошлого шага
			local side = 1

			cmaid:Give(RunService.Heartbeat:Connect(function()
				if humanoid.Health <= 0 then
					return
				end
				local pos = root.Position
				local dx, dz = pos.X - lastPos.X, pos.Z - lastPos.Z
				lastPos = pos

				-- В воздухе следов нет; дистанция обнуляется
				if humanoid.FloorMaterial == Enum.Material.Air then
					travelled = 0
					return
				end
				local moved = math.sqrt(dx * dx + dz * dz)
				if moved > 6 then -- телепорт
					travelled = 0
					return
				end
				local vel = root.AssemblyLinearVelocity
				local horizontal = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
				if horizontal < 2 then
					travelled = 0
					return
				end

				travelled += moved
				local sprinting = horizontal > 20
				local stride = sprinting and 3.4 or 2.3 -- расстояние между шагами
				if travelled < stride then
					return
				end
				travelled = 0

				-- Луч вниз находит пол прямо под ногами
				local result = Raycast(root.Position, Vector3.new(0, -6, 0), char, true)
				if not result then
					return
				end
				local forward = Vector3.new(vel.X, 0, vel.Z)
				forward = forward - result.Normal * forward:Dot(result.Normal) -- проекция на плоскость пола
				if forward.Magnitude < 1e-3 then
					return
				end
				side = -side
				place(result.Position, result.Normal, forward.Unit, side, sprinting)
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		for _, rec in ipairs(all) do
			if rec.Tween then
				rec.Tween:Cancel()
				rec.Tween = nil
			end
			rec.Part:Destroy()
		end
		pool, all = {}, {}
	end

	return M
end)()


-- ----------------------------------------------------------------------------
-- 7.4 Общие хелперы экипировки и свечения
-- ----------------------------------------------------------------------------
--- Мягкое свечение из вложенных полупрозрачных кругов (BillboardGui, размер в студах)
local function BuildGlow(parent, adornee, studs, alpha)
	local gui = Create("BillboardGui", {
		Name = "NN_Glow", Adornee = adornee, AlwaysOnTop = false, LightInfluence = 0,
		Size = UDim2.fromScale(studs, studs), Parent = parent,
	})
	local layers = {}
	for i, scale in ipairs({ 1, 0.78, 0.58, 0.4, 0.26 }) do
		layers[i] = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(scale, scale), BackgroundTransparency = alpha or 0.9, BorderSizePixel = 0, Parent = gui,
		}, { Corner(UDim.new(1, 0)) })
	end
	return gui, layers
end

local function GearColor()
	return GEAR_COLORS[Settings.GearColor].Color
end

local function ApplyGearLook(part, material, color)
	part.Material = material
	part.Color = color
	part.Reflectance = 0
	if material == Enum.Material.Glass then
		part.Transparency = 0.35
		part.Reflectance = 0.1
	elseif material == Enum.Material.Neon then
		part.Transparency = 0.08
	else
		part.Transparency = 0
	end
end

local function GetTorso(char, humanoid)
	return char:WaitForChild(humanoid.RigType == Enum.HumanoidRigType.R15 and "UpperTorso" or "Torso", 10)
end

-- ----------------------------------------------------------------------------
-- 7.5 Cape: плащ ИЗ ОДНОГО БЛОКА на шарнире (пружина зависит от скорости и падения)
-- ----------------------------------------------------------------------------
Modules.Cape = (function()
	local M = {}
	local maid

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or not isAlive() then
				return
			end
			local torso = GetTorso(char, humanoid)
			if not torso or not isAlive() then
				return
			end
			local torsoName = torso.Name

			local width = math.clamp(torso.Size.X * 0.95, 1.4, 2.4)
			local height, thickness = 3.3, 0.1
			local anchorLocal = Vector3.new(0, torso.Size.Y * 0.5 - 0.1, torso.Size.Z * 0.5 + 0.05)

			local block = Create("Part", {
				Name = "NN_Cape", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
				Massless = true, CastShadow = false, Size = Vector3.new(width, height, thickness), Parent = FxFolder,
			})
			cmaid:Give(block)
			ApplyGearLook(block, CAPE_MATERIALS[Settings.CapeMaterial].Material, GearColor())

			-- Две пружины: наклон назад (angle) и раскачивание в стороны (roll)
			local angle, angVel, roll, rollVel = 0.05, 0, 0, 0
			cmaid:Give(RunService.RenderStepped:Connect(function(dt)
				if not root.Parent then
					return
				end
				-- торс ищется заново каждый кадр: при смене аватара плащ не слетает
				local torso = char:FindFirstChild(torsoName) or root
				dt = math.min(dt, 0.1)
				local rootCF = root.CFrame
				local vel = root.AssemblyLinearVelocity
				local forwardSpeed = vel:Dot(rootCF.LookVector)
				local sideSpeed = vel:Dot(rootCF.RightVector)
				local speedFactor = math.clamp(vel.Magnitude / 30, 0, 1)

				-- Бег вперёд отбрасывает плащ назад; падение раздувает его вверх
				local target = 0.05 + math.clamp(forwardSpeed * 0.035, 0, 1.0)
				target += math.clamp(-vel.Y * 0.012, 0, 0.9)
				target += math.sin(os.clock() * 9) * 0.04 * speedFactor
				local rollTarget = math.clamp(-sideSpeed * 0.02, -0.5, 0.5)

				local k, c = 110, 11
				angVel += ((target - angle) * k - angVel * c) * dt
				angle = math.clamp(angle + angVel * dt, 0.03, 1.45)
				rollVel += ((rollTarget - roll) * k - rollVel * c) * dt
				roll += rollVel * dt

				local anchor = torso.CFrame:PointToWorldSpace(anchorLocal)
				local torsoCF = torso.CFrame
				local rot = torsoCF - torsoCF.Position -- ориентация берётся от торса: плащ как приклеенный
				-- шарнир наверху: поворот вокруг X отклоняет низ блока назад (+Z корня)
				block.CFrame = CFrame.new(anchor) * rot * CFrame.Angles(-angle, 0, roll) * CFrame.new(0, -height / 2, thickness / 2)
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 7.7 OrbitAura: шары на орбитах с лентами; у каждого шара своя пружина (bounce при ходьбе и прыжке)
-- ----------------------------------------------------------------------------
Modules.OrbitAura = (function()
	local M = {}
	local maid

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not root or not isAlive() then
				return
			end
			local folder = Create("Folder", { Name = "NN_OrbitAura", Parent = FxFolder })
			cmaid:Give(folder)

			local orbs = {}
			for i = 1, Settings.OrbitCount do
				local part = Create("Part", {
					Name = "Orb" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5),
					Material = Enum.Material.Neon, Anchored = true, CanCollide = false, CanQuery = false,
					CanTouch = false, CastShadow = false, Parent = folder,
				})
				local a0 = Create("Attachment", { Position = Vector3.new(0, 0.28, 0), Parent = part })
				local a1 = Create("Attachment", { Position = Vector3.new(0, -0.28, 0), Parent = part })
				local trail = Create("Trail", {
					Attachment0 = a0, Attachment1 = a1, Lifetime = 0.9, MinLength = 0.02, FaceCamera = true,
					LightEmission = 1, LightInfluence = 0,
					Transparency = NS({ NSK(0, 0.05), NSK(1, 1) }),
					WidthScale = NS({ NSK(0, 1), NSK(1, 0.1) }),
					Parent = part,
				})
				local _, layers = BuildGlow(part, part, 2.4, 0.9)
				local ring = (i - 1) % 2 + 1
				orbs[i] = {
					Part = part, Trail = trail, Layers = layers, Ring = ring,
					Phase = math.floor((i - 1) / 2) * (math.pi * 2 / math.ceil(Settings.OrbitCount / 2)),
					Dir = ring == 1 and 1 or -0.8,
					-- пружина: разная жёсткость и "ленивость" у каждого шара, чтобы не выглядели приклеенными
					Off = Vector3.zero, OffVel = Vector3.zero, K = 45 + i * 9, Lag = 0.05 + i * 0.006,
				}
			end

			local function applyColors()
				local A, B = Palette.GetColors()
				for i, orb in ipairs(orbs) do
					local c = (i % 2 == 0) and A or B
					orb.Part.Color = c
					orb.Trail.Color = ColorSequence.new(c, (i % 2 == 0) and B or A)
					for _, layer in ipairs(orb.Layers) do
						layer.BackgroundColor3 = c
					end
				end
			end
			applyColors()
			cmaid:Give(Palette.Changed.Event:Connect(applyColors))

			local parts, cframes = {}, {}
			for i, orb in ipairs(orbs) do
				parts[i] = orb.Part
				cframes[i] = CFrame.new()
			end

			local angleBase, colorTimer, smooth = 0, 0, 0
			cmaid:Give(RunService.RenderStepped:Connect(function(dt)
				if not root.Parent then
					return
				end
				dt = math.min(dt, 0.1)
				local vel = root.AssemblyLinearVelocity
				local horizontal = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
				smooth += (vel.Magnitude - smooth) * ExpAlpha(6, dt)
				local speedFactor = math.clamp(horizontal / 20, 0, 1)
				angleBase += dt * 1.5 * (1 + math.clamp(smooth / 40, 0, 0.8))
				local t = os.clock()
				-- покачивание в такт шагам
				local bob = math.sin(t * (7 + speedFactor * 3)) * 0.18 * speedFactor
				local center = root.Position + Vector3.new(0, 0.3 + math.sin(t * 1.3) * 0.2, 0)
				local yaw = t * 0.3

				for i, orb in ipairs(orbs) do
					-- цель пружины: шар отстаёт от движения (бег, прыжок, падение) и затем возвращается с отскоком
					local target = Vector3.new(-vel.X, -vel.Y * 0.6, -vel.Z) * orb.Lag
					if target.Magnitude > 1.8 then
						target = target.Unit * 1.8
					end
					local acc = (target - orb.Off) * orb.K - orb.OffVel * 7
					orb.OffVel += acc * dt
					orb.Off += orb.OffVel * dt

					local tilt = orb.Ring == 1 and math.rad(28) or math.rad(-28)
					local plane = CFrame.new(center) * CFrame.Angles(0, yaw + (orb.Ring - 1) * math.pi / 2, 0) * CFrame.Angles(0, 0, tilt)
					local theta = angleBase * orb.Dir + orb.Phase
					local local_ = Vector3.new(math.cos(theta) * 3.4, 0, math.sin(theta) * 2.9)
					local bobI = (i % 2 == 0) and bob * 0.4 or -bob * 0.4
					cframes[i] = CFrame.new(plane:PointToWorldSpace(local_) + orb.Off + Vector3.new(0, bob + bobI, 0))
				end
				Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)

				if Palette.IsRainbow() then
					colorTimer += dt
					if colorTimer > 0.1 then
						colorTimer = 0
						applyColors()
					end
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 7.8 GlowHat: коническая шляпа из светящихся лучей (Beam) - без блоков и текстур
-- ----------------------------------------------------------------------------
Modules.GlowHat = (function()
	local M = {}
	local maid
	local SIDES = 12

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local head = char:WaitForChild("Head", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not head or not root or not isAlive() then
				return
			end
			-- шляпа крепится к корню (его не заменяет смена внешности); смещение головы берётся один раз
			local headOffset = root.CFrame:PointToObjectSpace(head.Position)
			local size = Settings.HatSize / 100
			local baseY = head.Size.Y * 0.5 - 0.05 + Settings.HatHeight / 10 -- высота: смещение вверх / вниз
			local brimR, hatH = 1.65 * size, 0.75 * size -- широкие поля и низкий конус
			local midH = 0.38 * size
			local wk = math.clamp(size, 0.75, 1.5) -- толщина лучей растёт вместе с размером
			local midR = brimR * (1 - midH / hatH)

			local function point(radius, height, k)
				local a = (k - 1) / SIDES * math.pi * 2
				return Vector3.new(math.cos(a) * radius, baseY + height, math.sin(a) * radius)
			end
			local function att(pos)
				local a = Create("Attachment", { Position = headOffset + pos, Parent = root })
				cmaid:Give(a)
				return a
			end

			local brim, mid = {}, {}
			for k = 1, SIDES do
				brim[k] = att(point(brimR, -0.1, k))
				mid[k] = att(point(midR, midH, k))
			end
			local tip = att(Vector3.new(0, baseY + hatH, 0))

			local beams = {}
			local function beam(a0, a1, width)
				local b = Create("Beam", {
					Attachment0 = a0, Attachment1 = a1, Width0 = width, Width1 = width, Segments = 1,
					LightEmission = 1, LightInfluence = 0, FaceCamera = true,
					Transparency = NS(0.1), Parent = root,
				})
				cmaid:Give(b)
				beams[#beams + 1] = b
			end
			for k = 1, SIDES do
				local nxt = k % SIDES + 1
				beam(brim[k], tip, 0.05 * wk)        -- рёбра конуса
				beam(brim[k], brim[nxt], 0.09 * wk)  -- поля шляпы
				beam(mid[k], mid[nxt], 0.045 * wk)   -- средний обруч
			end

			-- Мягкое свечение вокруг шляпы и искры на кончике
			local gui, layers = BuildGlow(root, root, 3.4 * size, 0.93)
			gui.StudsOffsetWorldSpace = Vector3.new(0, headOffset.Y + baseY + 0.3, 0)
			cmaid:Give(gui)
			local sparkAtt = att(Vector3.new(0, baseY + hatH, 0))
			local sparks = Create("ParticleEmitter", {
				Rate = 4, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
				SpreadAngle = Vector2.new(60, 60), Acceleration = Vector3.new(0, 1.5, 0),
				Size = NS({ NSK(0, 0.25), NSK(1, 0) }), Transparency = NS({ NSK(0, 0), NSK(1, 1) }),
				LightEmission = 1, LightInfluence = 0, Parent = sparkAtt,
			})

			local function applyColors()
				local A, B = Palette.GetColors()
				local seq = ColorSequence.new(A, B)
				for _, b in ipairs(beams) do
					b.Color = seq
				end
				sparks.Color = Palette.Sequence()
				for i, layer in ipairs(layers) do
					layer.BackgroundColor3 = A:Lerp(B, (i - 1) / (#layers - 1))
				end
			end
			applyColors()
			cmaid:Give(Palette.Changed.Event:Connect(applyColors))
			if Palette.IsRainbow() or true then
				local timer = 0
				cmaid:Give(RunService.Heartbeat:Connect(function(dt)
					timer += dt
					if timer > 0.12 then
						timer = 0
						if Palette.IsRainbow() then
							applyColors()
						end
					end
				end))
			end
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	--- Пересобрать шляпу после смены размера / высоты (с небольшой задержкой, чтобы слайдер не душил игру)
	local rebuildToken = 0
	function M.Rebuild()
		rebuildToken += 1
		local mine = rebuildToken
		task.delay(0.15, function()
			if mine == rebuildToken and maid then
				M.Disable()
				M.Enable()
			end
		end)
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 7.9 WalkWaves: волны от шагов, прыжка и приземления (интервал и дальность настраиваются)
-- ----------------------------------------------------------------------------
Modules.WalkWaves = (function()
	local M = {}
	local maid
	local pool, all = {}, {}

	local function release(rec)
		if rec.Tweens then
			for _, tw in ipairs(rec.Tweens) do
				tw:Cancel()
			end
			rec.Tweens = nil
		end
		rec.Part.Parent = nil
		pool[#pool + 1] = rec
	end

	local function newRing()
		local part = Create("Part", {
			Name = "NN_Wave", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, Transparency = 1, Size = Vector3.new(0.5, 0.05, 0.5),
		})
		local surface = Create("SurfaceGui", {
			Face = Enum.NormalId.Top, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			CanvasSize = Vector2.new(256, 256), LightInfluence = 0, Parent = part,
		})
		pcall(function()
			surface.Brightness = 3 -- неоновая яркость
		end)
		-- два вложенных кольца: широкое мягкое свечение и тонкое яркое ядро
		local glow = Create("UIStroke", { Thickness = 30, Transparency = 0.75 })
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
			BackgroundTransparency = 1, Parent = surface,
		}, { Corner(UDim.new(1, 0)), glow })
		local stroke = Create("UIStroke", { Thickness = 8, Transparency = 0.05 })
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.86, 0.86),
			BackgroundTransparency = 1, Parent = surface,
		}, { Corner(UDim.new(1, 0)), stroke })
		local rec = { Part = part, Stroke = stroke, Glow = glow }
		all[#all + 1] = rec
		return rec
	end

	local function ripple(position, normal, diameter, duration, color, delay)
		local function spawn()
			local rec = table.remove(pool) or newRing()
			if rec.Tweens then
				for _, tw in ipairs(rec.Tweens) do
					tw:Cancel()
				end
			end
			rec.Part.Size = Vector3.new(0.6, 0.05, 0.6)
			rec.Part.CFrame = CFrame.lookAt(position + normal * 0.05, position + normal * 1.05) * CFrame.Angles(-math.pi / 2, 0, 0)
			rec.Stroke.Color = color:Lerp(Color3.new(1, 1, 1), 0.4) -- светлое ядро
			rec.Stroke.Transparency = 0.05
			rec.Glow.Color = color
			rec.Glow.Transparency = 0.7
			rec.Part.Parent = FxFolder
			local grow = TweenService:Create(rec.Part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(diameter, 0.05, diameter) })
			local fade = TweenService:Create(rec.Stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			local fadeGlow = TweenService:Create(rec.Glow, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			rec.Tweens = { grow, fade, fadeGlow }
			grow.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed and rec.Tweens and rec.Tweens[1] == grow then
					release(rec)
				end
			end)
			grow:Play()
			fade:Play()
			fadeGlow:Play()
		end
		if delay and delay > 0 then
			task.delay(delay, spawn)
		else
			spawn()
		end
	end

	local function floorBelow(root, char)
		return Raycast(root.Position, Vector3.new(0, -7, 0), char, true)
	end

	--- Дальность волн (радиус, студы) -> диаметр кольца и длительность расхождения
	local function sizes(multiplier)
		local diameter = Settings.WaveRange * 2 * (multiplier or 1)
		return diameter, math.clamp(0.55 + Settings.WaveRange * 0.05, 0.6, 1.8)
	end

	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or not isAlive() then
				return
			end

			local timer, flip = 0, false
			cmaid:Give(RunService.Heartbeat:Connect(function(dt)
				if humanoid.Health <= 0 then
					return
				end
				timer += dt
				if humanoid.FloorMaterial == Enum.Material.Air then
					return
				end
				local vel = root.AssemblyLinearVelocity
				local horizontal = math.sqrt(vel.X * vel.X + vel.Z * vel.Z)
				if horizontal < 2 then
					return
				end
				-- интервал между волнами задаётся в секундах (шаг слайдера 0.1 с)
				if timer < Settings.WaveInterval * 0.1 then
					return
				end
				timer = 0
				local hit = floorBelow(root, char)
				if hit then
					flip = not flip
					local A, B = Palette.GetColors()
					local c = flip and A or B
					local sprinting = horizontal > 20
					local d, dur = sizes(sprinting and 1.3 or 1)
					ripple(hit.Position, hit.Normal, d, dur, c, 0)
					ripple(hit.Position, hit.Normal, d * 0.55, dur * 0.8, c, 0.1)
				end
			end))

			cmaid:Give(humanoid.StateChanged:Connect(function(_, new)
				if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Landed then
					local hit = floorBelow(root, char)
					if hit then
						local A, B = Palette.GetColors()
						local big = new == Enum.HumanoidStateType.Landed
						local d, dur = sizes(big and 1.6 or 1.1)
						ripple(hit.Position, hit.Normal, d, dur, A, 0)
						ripple(hit.Position, hit.Normal, d * 0.6, dur * 0.8, B, 0.12)
					end
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		for _, rec in ipairs(all) do
			if rec.Tweens then
				for _, tw in ipairs(rec.Tweens) do
					tw:Cancel()
				end
				rec.Tweens = nil
			end
			rec.Part:Destroy()
		end
		pool, all = {}, {}
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.1 HitFX: 3D-взрыв частиц и колец в точке клика / при анимации атаки
-- ----------------------------------------------------------------------------
Modules.HitFX = (function()
	local M = {}
	local maid
	local lastBurst = 0

	local ATTACK_KEYWORDS = { "attack", "slash", "swing", "punch", "hit", "strike", "kick", "stab", "swipe", "melee", "combo" }

	--- Публичная функция-хук: Modules.HitFX.Burst(позиция, нормаль, масштаб)
	--- Доступна всегда (в т.ч. через _G.NNProject.HitBurst), даже если модуль выключен.
	function M.Burst(position, normal, scale)
		normal = normal or Vector3.yAxis
		scale = scale or 1
		local A, B = Palette.GetColors()
		local sequence = Palette.Sequence()

		-- Ось Y якоря = нормаль поверхности (EmissionDirection.Top выстреливает вдоль неё)
		local orient = CFrame.lookAt(position, position + normal) * CFrame.Angles(-math.pi / 2, 0, 0)

		local anchor = Create("Part", {
			Name = "NN_HitFX",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			Transparency = 1,
			Size = Vector3.new(0.2, 0.2, 0.2),
			CFrame = orient,
			Parent = FxFolder,
		})

		-- Искры: конус вокруг нормали, гравитация и сопротивление воздуха
		local sparks = Create("ParticleEmitter", {
			Rate = 0,
			Color = sequence,
			Lifetime = NumberRange.new(0.35, 0.8),
			Speed = NumberRange.new(18 * scale, 42 * scale),
			SpreadAngle = Vector2.new(55, 55),
			Drag = 2.5,
			Acceleration = Vector3.new(0, -35, 0),
			Size = NS({ NSK(0, 0.55), NSK(1, 0) }),
			Transparency = NS({ NSK(0, 0), NSK(0.7, 0.2), NSK(1, 1) }),
			LightEmission = 1,
			LightInfluence = 0,
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-200, 200),
			EmissionDirection = Enum.NormalId.Top,
			Parent = anchor,
		})
		sparks:Emit(math.floor(26 * scale))

		-- Вспышка: один большой быстрый спрайт
		local flash = Create("ParticleEmitter", {
			Rate = 0,
			Color = ColorSequence.new(B),
			Lifetime = NumberRange.new(0.18, 0.25),
			Speed = NumberRange.new(0, 0),
			Size = NS({ NSK(0, 3 * scale), NSK(1, 8 * scale) }),
			Transparency = NS({ NSK(0, 0.2), NSK(1, 1) }),
			LightEmission = 1,
			LightInfluence = 0,
			Parent = anchor,
		})
		flash:Emit(1)

		-- Медленные угольки
		local embers = Create("ParticleEmitter", {
			Rate = 0,
			Color = sequence,
			Lifetime = NumberRange.new(0.8, 1.3),
			Speed = NumberRange.new(4, 9),
			SpreadAngle = Vector2.new(80, 80),
			Acceleration = Vector3.new(0, 4, 0),
			Size = NS({ NSK(0, 0.35), NSK(1, 0) }),
			Transparency = NS({ NSK(0, 0), NSK(1, 1) }),
			LightEmission = 1,
			LightInfluence = 0,
			EmissionDirection = Enum.NormalId.Top,
			Parent = anchor,
		})
		embers:Emit(10)

		-- Кольцо-ударная волна, лежащее на поверхности (SurfaceGui на тонкой детали)
		local ringPart = Create("Part", {
			Name = "NN_Ring",
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Transparency = 1,
			Size = Vector3.new(0.5, 0.05, 0.5),
			CFrame = CFrame.lookAt(position + normal * 0.06, position + normal * 1.06) * CFrame.Angles(-math.pi / 2, 0, 0),
			Parent = FxFolder,
		})
		local surface = Create("SurfaceGui", {
			Face = Enum.NormalId.Top,
			SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
			CanvasSize = Vector2.new(256, 256), -- фиксированный холст: кольцо масштабируется вместе с деталью
			LightInfluence = 0,
			Parent = ringPart,
		})
		local ringStroke = Create("UIStroke", { Color = A, Thickness = 14, Transparency = 0 })
		Create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Parent = surface,
		}, { Corner(UDim.new(1, 0)), ringStroke })
		local d = 18 * scale
		Tween(ringPart, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(d, 0.05, d) })
		Tween(ringStroke, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })

		-- Второе кольцо: всегда лицом к камере, чуть позже
		local billboard = Create("BillboardGui", {
			Adornee = anchor,
			Size = UDim2.fromScale(0.5, 0.5), -- масштаб BillboardGui = студы
			StudsOffsetWorldSpace = normal * 0.8,
			LightInfluence = 0,
			Parent = anchor,
		})
		local bbStroke = Create("UIStroke", { Color = B, Thickness = 4, Transparency = 0.1 })
		Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = billboard }, { Corner(UDim.new(1, 0)), bbStroke })
		task.delay(0.06, function()
			if billboard.Parent then
				Tween(billboard, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromScale(10 * scale, 10 * scale) })
				Tween(bbStroke, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
			end
		end)

		Debris:AddItem(anchor, 1.8)
		Debris:AddItem(ringPart, 0.9)
	end

	function M.Enable() end
	function M.Disable() end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.3 ScreenShake: модульная тряска камеры (sin или Perlin-шум), несколько тряск складываются
-- ----------------------------------------------------------------------------
Modules.ScreenShake = (function()
	local M = {}
	local BIND = "NNProject_ScreenShake"
	local active = {}
	local bound = false
	local lastOffset = nil
	local maid

	M.Presets = {
		Light = { 0.12, 0.20 },
		Medium = { 0.30, 0.35 },
		Heavy = { 0.70, 0.55 },
		Explosion = { 1.40, 0.90, { Frequency = 30, Rotation = 1.4 } },
	}

	local function unbind()
		if not bound then
			return
		end
		bound = false
		RunService:UnbindFromRenderStep(BIND)
	end

	-- Выполняется сразу ПОСЛЕ камерного скрипта Roblox (RenderPriority.Camera + 1):
	-- стандартная камера каждый кадр пересчитывает CFrame с нуля, поэтому смещение не накапливается.
	local function step()
		local cam = GetCamera()
		if not cam then
			return
		end
		-- Для Scriptable-камеры (её CFrame никто не сбрасывает) снимаем прошлое смещение вручную
		if lastOffset then
			if cam.CameraType == Enum.CameraType.Scriptable then
				cam.CFrame = cam.CFrame * lastOffset:Inverse()
			end
			lastOffset = nil
		end
		if #active == 0 then
			task.defer(unbind)
			return
		end

		local now = os.clock()
		local px, py, pz, rx, ry, rz = 0, 0, 0, 0, 0, 0
		for i = #active, 1, -1 do
			local s = active[i]
			local elapsed = now - s.Start
			if elapsed >= s.Duration then
				table.remove(active, i)
			else
				-- Амплитуда = интенсивность * (1 - прогресс)^Decay * плавный вход
				local alpha = elapsed / s.Duration
				local fadeIn = math.min(elapsed / s.FadeIn, 1)
				local amp = s.Intensity * ((1 - alpha) ^ s.Decay) * fadeIn
				local t = elapsed * s.Frequency
				local nx, ny, nz
				if s.Mode == "noise" then
					-- Perlin-шум: случайная, но плавная тряска
					nx = math.noise(t, s.Seed, 0.5) * 2
					ny = math.noise(s.Seed, t, 2.5) * 2
					nz = math.noise(t, 4.5, s.Seed) * 2
				else
					-- Синусы с несоизмеримыми частотами и случайными фазами
					nx = math.sin(t + s.Seed)
					ny = math.sin(t * 1.31 + s.Seed * 2.1)
					nz = math.sin(t * 0.77 + s.Seed * 3.7)
				end
				px += nx * amp
				py += ny * amp
				pz += nz * amp * 0.35
				local rot = amp * 1.2 * s.Rotation -- градусы
				rx += ny * rot
				ry += nx * rot
				rz += nz * rot * 1.5
			end
		end

		local offset = CFrame.new(px, py, pz) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
		cam.CFrame = cam.CFrame * offset
		lastOffset = offset
	end

	local function bind()
		if bound then
			return
		end
		bound = true
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, step)
	end

	--- Shake(intensity, duration, options)
	---   intensity  - амплитуда в студах (0.1 слабо, 0.7 сильно, 1.4 взрыв)
	---   duration   - длительность в секундах
	---   options    - { Frequency=22, Rotation=1, Mode="sin"|"noise", Decay=2, FadeIn=0.04 }
	--- Работает всегда, независимо от переключателя модуля.
	function M.Shake(intensity, duration, options)
		options = options or {}
		active[#active + 1] = {
			Start = os.clock(),
			Intensity = intensity or 0.3,
			Duration = math.max(duration or 0.4, 0.05),
			Frequency = options.Frequency or 22,
			Rotation = options.Rotation or 1,
			Mode = options.Mode or "sin",
			Decay = options.Decay or 2,
			FadeIn = math.max(options.FadeIn or 0.04, 0.001),
			Seed = math.random() * 100,
		}
		bind()
	end

	function M.Stop()
		active = {}
	end

	-- Включение модуля = автоматическая тряска при получении урона (сила зависит от урона)
	function M.Enable()
		maid = Maid.new()
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			if not humanoid or not isAlive() then
				return
			end
			local last = humanoid.Health
			cmaid:Give(humanoid.HealthChanged:Connect(function(health)
				local delta = last - health
				last = health
				if delta > 0.5 then
					local ratio = math.clamp(delta / math.max(humanoid.MaxHealth, 1), 0, 1)
					M.Shake(math.clamp(0.18 + ratio * 2.4, 0.18, 1.6), 0.3 + ratio * 0.9, { Mode = "noise", Frequency = 26, Rotation = 1.2 })
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()


-- ----------------------------------------------------------------------------
-- 8.4 Atmosphere (теперь "Кино-свечение"): bloom + блюр на высокой скорости
-- ----------------------------------------------------------------------------
Modules.Atmosphere = (function()
	local M = {}
	local S = {}
	local maid
	local token = 0

	function M.Enable()
		token += 1
		maid = Maid.new()
		if not S.bloom or not S.bloom.Parent then
			S.bloom = Create("BloomEffect", { Name = "NN_Bloom", Intensity = 0, Size = 24, Threshold = 1.0, Parent = Lighting })
		end
		if not S.blur or not S.blur.Parent then
			S.blur = Create("BlurEffect", { Name = "NN_SpeedBlur", Size = 0, Parent = Lighting })
		end
		Tween(S.bloom, TweenInfo.new(1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Intensity = Settings.GlowPower / 100 * 1.2, Size = 30 })
		maid:Give(RunService.Heartbeat:Connect(function(dt)
			local root = GetRoot()
			if not root or not S.blur or not S.blur.Parent then
				return
			end
			local target = math.clamp((root.AssemblyLinearVelocity.Magnitude - 26) / 50, 0, 1) * (Settings.BlurPower / 100 * 20)
			S.blur.Size += (target - S.blur.Size) * ExpAlpha(6, dt)
		end))
	end

	--- Мгновенно применяет силу свечения (вызывается слайдером)
	function M.Refresh()
		if S.bloom and S.bloom.Parent then
			Tween(S.bloom, TI.Fast, { Intensity = Settings.GlowPower / 100 * 1.2 })
		end
	end

	local function destroyAll()
		for _, key in ipairs({ "bloom", "blur" }) do
			if S[key] then
				S[key]:Destroy()
				S[key] = nil
			end
		end
	end

	function M.Disable()
		token += 1
		local mine = token
		if maid then
			maid:Clean()
			maid = nil
		end
		if S.bloom then
			local info = TweenInfo.new(1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			Tween(S.bloom, info, { Intensity = 0 })
			if S.blur then
				Tween(S.blur, info, { Size = 0 })
			end
			task.delay(1.4, function()
				if token == mine then
					destroyAll()
				end
			end)
		end
	end

	function M.Destroy()
		token += 1
		if maid then
			maid:Clean()
			maid = nil
		end
		destroyAll()
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.5 Env: туман и цветокоррекция (есть пресеты и "Кастом." с выбором цвета)
-- ----------------------------------------------------------------------------
local Env = {}
local envState = {}

local function envLightingOrig()
	if not envState.lighting then
		envState.lighting = { FogStart = Lighting.FogStart, FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor }
	end
	return envState.lighting
end

local function envAtmosphere()
	if envState.atmo and not envState.atmo.Parent then
		envState.atmo = nil
	end
	if not envState.atmo then
		local existing = Lighting:FindFirstChildOfClass("Atmosphere")
		if existing then
			envState.atmo = existing
			envState.owned = false
			envState.atmoOrig = {
				Density = existing.Density, Haze = existing.Haze, Offset = existing.Offset,
				Glare = existing.Glare, Color = existing.Color, Decay = existing.Decay,
			}
		else
			envState.atmo = Create("Atmosphere", {
				Name = "NN_Atmosphere", Density = 0, Haze = 0, Offset = 0.25, Glare = 0,
				Color = Color3.fromRGB(190, 186, 210), Decay = Color3.fromRGB(100, 95, 125), Parent = Lighting,
			})
			envState.owned = true
			envState.atmoOrig = { Density = 0, Haze = 0 }
		end
	end
	return envState.atmo
end

--- Параметры кастомного тумана по силе (1-100): ближе и плотнее при большем значении
local function customFog()
	local k = Settings.FogStrength / 100
	return { Start = Lerp(120, 0, k), End = Lerp(1600, 140, k), Density = 0.05 + k * 0.6, Haze = k * 4 }
end

function Env.SetFog(index)
	Settings.Fog = index
	local info = TweenInfo.new(1.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	local orig = envLightingOrig()
	if index == 1 then
		Tween(Lighting, info, orig)
		if envState.atmo and envState.atmoOrig then
			Tween(envState.atmo, info, envState.atmoOrig)
			if envState.owned then
				local atmo = envState.atmo
				task.delay(1.4, function()
					if Settings.Fog == 1 and atmo.Parent then
						atmo:Destroy()
						if envState.atmo == atmo then
							envState.atmo = nil
						end
					end
				end)
			end
		end
		return
	end
	local mode = FOG_MODES[index]
	if mode.Custom then
		local c = customFog()
		mode = { Custom = true, Start = c.Start, End = c.End, Density = c.Density, Haze = c.Haze }
	end
	local color = mode.Custom and Settings.FogColor or mode.Color
	Tween(Lighting, info, { FogStart = mode.Start, FogEnd = mode.End, FogColor = color })
	Tween(envAtmosphere(), info, { Density = mode.Density, Haze = mode.Haze, Color = color })
end

--- Мгновенное обновление тумана (цвет и сила) при перетаскивании пикера/слайдера
function Env.LiveFog()
	if not FOG_MODES[Settings.Fog].Custom then
		return
	end
	local c = customFog()
	Lighting.FogColor = Settings.FogColor
	Lighting.FogStart = c.Start
	Lighting.FogEnd = c.End
	if envState.atmo then
		envState.atmo.Color = Settings.FogColor
		envState.atmo.Density = c.Density
		envState.atmo.Haze = c.Haze
	end
end

function Env.SetGrade(index)
	Settings.Grade = index
	local info = TweenInfo.new(1.0, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	if not envState.cc or not envState.cc.Parent then
		envState.cc = Create("ColorCorrectionEffect", { Name = "NN_Grade", Parent = Lighting })
	end
	local cc = envState.cc
	local preset = GRADES[index]
	if index == 1 then
		Tween(cc, info, { Contrast = 0, Saturation = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
		task.delay(1.2, function()
			if Settings.Grade == 1 and cc.Parent then
				cc:Destroy()
				if envState.cc == cc then
					envState.cc = nil
				end
			end
		end)
	else
		local tint = preset.Custom and Settings.GradeTint or preset.Tint
		Tween(cc, info, { Contrast = preset.Contrast, Saturation = preset.Saturation, Brightness = preset.Brightness, TintColor = tint })
	end
end

function Env.LiveGrade()
	if GRADES[Settings.Grade].Custom and envState.cc then
		envState.cc.TintColor = Settings.GradeTint
	end
end

function Env.Destroy()
	if envState.lighting then
		pcall(function()
			Lighting.FogStart = envState.lighting.FogStart
			Lighting.FogEnd = envState.lighting.FogEnd
			Lighting.FogColor = envState.lighting.FogColor
		end)
	end
	if envState.cc then
		envState.cc:Destroy()
	end
	if envState.atmo then
		if envState.owned then
			envState.atmo:Destroy()
		elseif envState.atmoOrig then
			for key, value in pairs(envState.atmoOrig) do
				pcall(function()
					envState.atmo[key] = value
				end)
			end
		end
	end
	envState = {}
end

-- ----------------------------------------------------------------------------
-- 8.6 TimeCtl: фиксированное время суток (плавный переход, "Игровое" = не трогаем)
-- ----------------------------------------------------------------------------
local TimeCtl = {}

function TimeCtl.Set(index)
	Settings.Time = index
	if TimeCtl.connection then
		TimeCtl.connection:Disconnect()
		TimeCtl.connection = nil
	end
	local preset = TIME_PRESETS[index]
	if not preset.Clock then
		return
	end
	TimeCtl.connection = RunService.Heartbeat:Connect(function(dt)
		local cur = Lighting.ClockTime
		local diff = ((preset.Clock - cur + 12) % 24) - 12 -- кратчайший путь по кругу суток
		if math.abs(diff) < 0.01 then
			Lighting.ClockTime = preset.Clock
		else
			Lighting.ClockTime = (cur + diff * ExpAlpha(2.5, dt)) % 24
		end
	end)
end

function TimeCtl.Destroy()
	if TimeCtl.connection then
		TimeCtl.connection:Disconnect()
		TimeCtl.connection = nil
	end
end

-- ----------------------------------------------------------------------------
-- 8.7 Snow: крупный непрозрачный снег вокруг камеры (в помещении отключается)
-- ----------------------------------------------------------------------------
Modules.Snow = (function()
	local M = {}
	local maid

	function M.Enable()
		maid = Maid.new()
		local anchor = Create("Part", {
			Name = "NN_Snow", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(140, 1, 140), Parent = FxFolder,
		})
		maid:Give(anchor)
		local emitter = Create("ParticleEmitter", {
			Name = "Snow",
			Texture = CONFIG.SnowTexture,
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
			LightEmission = 0.35,
			LightInfluence = 0.2,
			Size = NS({ NSK(0, 0.8, 0.3), NSK(1, 0.9, 0.3) }), -- крупные хлопья с разбросом размера
			Transparency = NS({ NSK(0, 1), NSK(0.05, 0.05), NSK(0.9, 0.05), NSK(1, 1) }), -- почти непрозрачные
			Lifetime = NumberRange.new(6, 8),
			Rate = SNOW_LEVELS[Settings.SnowLevel].Rate,
			Speed = NumberRange.new(9, 14),
			SpreadAngle = Vector2.new(12, 12),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(3, 0, 1.5),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-40, 40),
			LockedToPart = false,
			Parent = anchor,
		})

		local indoorTimer = 0
		maid:Give(RunService.RenderStepped:Connect(function(dt)
			local cam = GetCamera()
			if not cam then
				return
			end
			local camPos = cam.CFrame.Position
			anchor.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
			indoorTimer += dt
			if indoorTimer > 0.3 then
				indoorTimer = 0
				-- Над камерой есть крыша: снег не идёт
				local roof = Raycast(camPos, Vector3.new(0, 70, 0), LocalPlayer.Character, true)
				emitter.Enabled = roof == nil
				local t = os.clock() * 0.1
				emitter.Acceleration = Vector3.new(math.noise(t, 0.5) * 8, 0, math.noise(0.5, t) * 6)
			end
		end))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.8 Fireflies: светлячки вокруг игрока (цвет и размер настраиваются)
-- ----------------------------------------------------------------------------
Modules.Fireflies = (function()
	local M = {}
	local maid, emitter

	--- Применяет цвет и размер из настроек (вызывается и слайдером, и пикером цвета)
	function M.Refresh()
		if not emitter or not emitter.Parent then
			return
		end
		local c = Settings.FireflyColor
		emitter.Color = ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.25), c)
		local s = Settings.FireflySize / 100 * 1.1
		emitter.Size = NS({ NSK(0, 0), NSK(0.2, s), NSK(0.8, s), NSK(1, 0) })
	end

	function M.Enable()
		maid = Maid.new()
		local anchor = Create("Part", {
			Name = "NN_Fireflies", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(70, 16, 70), Parent = FxFolder,
		})
		maid:Give(anchor)
		emitter = Create("ParticleEmitter", {
			Name = "Fireflies",
			LightEmission = 1, LightInfluence = 0,
			Transparency = NS({ NSK(0, 1), NSK(0.2, 0.1), NSK(0.8, 0.1), NSK(1, 1) }),
			Lifetime = NumberRange.new(6, 9), Rate = 14, Speed = NumberRange.new(0.3, 1.1),
			SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 0.2, 0), Drag = 0.5,
			LockedToPart = false, Parent = anchor,
		})
		M.Refresh()
		maid:Give(RunService.RenderStepped:Connect(function()
			local cam = GetCamera()
			if cam then
				anchor.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, -3, 0))
			end
		end))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		emitter = nil
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.9 Fov: управление полем зрения (значение задаётся слайдером)
-- ----------------------------------------------------------------------------
Modules.Fov = (function()
	local M = {}
	local BIND = "NNProject_Fov"
	local bound = false
	local original = 70

	function M.Enable()
		local cam = GetCamera()
		original = cam and cam.FieldOfView or 70
		if bound then
			return
		end
		bound = true
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
			if IsEnabled("ForceThird") then
				return
			end
			local c = GetCamera()
			if c then
				c.FieldOfView += (Settings.Fov - c.FieldOfView) * ExpAlpha(10, dt)
			end
		end)
	end

	function M.Disable()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(BIND)
		end
		local cam = GetCamera()
		if cam then
			Tween(cam, TI.Slow, { FieldOfView = original })
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.10 Target: таргет-эффект на игроке (и на ботах/Rig) в прицеле курсора или центра экрана.
-- Выбор цели "с допуском": берётся ближайшая к указателю фигура в радиусе, затем проверяется
-- прямая видимость лучом - сквозь стены цель не определяется.
-- ----------------------------------------------------------------------------
local Target = { AuraEnabled = false, InfoEnabled = false, RigsEnabled = false, Running = false, Current = nil, Char = nil, Auras = {} }

do
	local maid, ui
	local loseTimer, step = 0, 0
	local hpSmooth = 1
	local rigs = {} -- [Humanoid] = true: все гуманоиды карты (боты и обычные Rig)
	local infoShown = false

	--- Положение карточки цели: X и Y из настроек (в половинках процента экрана); hidden - позиция "уехавшей" карточки
	local function infoPos(hidden)
		return UDim2.new(Settings.TargetInfoX / 200, 0, Settings.TargetInfoY / 200, hidden and -110 or 0)
	end

	-- ---- панель информации (сверху по центру, под ватермаркой)
	local function ensureUi()
		if ui then
			return ui
		end
		local panel = Make("CanvasGroup", {
			Name = "TargetInfo", AnchorPoint = Vector2.new(0.5, 0), Position = infoPos(true),
			Size = UDim2.fromOffset(250, 76), GroupTransparency = 1, BorderSizePixel = 0,
			Skin = { BackgroundColor3 = "Background" }, Parent = ScreenGui,
		}, {
			Corner(UDim.new(0, 14)), Make("UIStroke", { Thickness = 1, Transparency = 0.3, Skin = { Color = "Stroke" } }),
			Create("UIScale", { Name = "Scale", Scale = Settings.TargetInfoScale / 100 }),
		})
		local avatar = Make("ImageLabel", {
			Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(56, 56), BorderSizePixel = 0,
			Skin = { BackgroundColor3 = "Panel" }, Parent = panel,
		}, { Corner(UDim.new(0, 10)) })
		local letter = Make("TextLabel", {
			BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 26,
			Text = "?", Skin = { TextColor3 = "AccentSoft" }, Parent = avatar,
		})
		local nameLabel = Create("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 8), Size = UDim2.new(1, -86, 0, 20),
			Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Parent = panel,
		})
		local userLabel = Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 28), Size = UDim2.new(1, -86, 0, 16),
			Font = Enum.Font.Gotham, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = "", Skin = { TextColor3 = "Muted" }, Parent = panel,
		})
		local hpLabel = Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(76, 44), Size = UDim2.new(1, -86, 0, 14),
			Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
			Text = "", Skin = { TextColor3 = "AccentSoft" }, Parent = panel,
		})
		local track = Make("Frame", {
			Position = UDim2.fromOffset(76, 62), Size = UDim2.new(1, -86, 0, 6), BorderSizePixel = 0,
			Skin = { BackgroundColor3 = "Panel" }, Parent = panel,
		}, { Corner(UDim.new(1, 0)) })
		local fill = Make("Frame", {
			Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, Skin = { BackgroundColor3 = "SwitchOn" }, Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		ui = { Panel = panel, Scale = panel.Scale, Avatar = avatar, Letter = letter, Name = nameLabel, User = userLabel, Hp = hpLabel, Fill = fill }
		return ui
	end

	local function showPanel(cand)
		local u = ensureUi()
		if cand.Player then
			u.Name.Text = cand.Player.DisplayName
			u.User.Text = "@" .. cand.Player.Name
			u.Avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", cand.Player.UserId)
			u.Letter.Visible = false
		else
			local shown = cand.Humanoid.DisplayName ~= "" and cand.Humanoid.DisplayName or cand.Model.Name
			u.Name.Text = shown
			u.User.Text = T("Бот / Rig: ") .. cand.Model.Name
			u.Avatar.Image = ""
			u.Letter.Text = string.upper(string.sub(shown, 1, 1))
			u.Letter.Visible = true
		end
		infoShown = true
		u.Scale.Scale = Settings.TargetInfoScale / 100
		Tween(u.Panel, TI.Medium, { Position = infoPos(false), GroupTransparency = 0 })
	end

	local function hidePanel()
		if ui then
			infoShown = false
			Tween(ui.Panel, TI.In, { Position = infoPos(true), GroupTransparency = 1 })
		end
	end

	--- Применить X / Y / размер сразу (двигаем слайдеры - карточка двигается)
	function Target.LayoutInfo()
		if not ui then
			return
		end
		ui.Scale.Scale = Settings.TargetInfoScale / 100
		if infoShown then
			Tween(ui.Panel, TI.Fast, { Position = infoPos(false) })
		else
			ui.Panel.Position = infoPos(true)
		end
	end

	--- Показать тестовую карточку на 4 секунды, чтобы настроить положение без реальной цели
	local previewToken = 0
	function Target.PreviewInfo()
		if Target.Current and Target.InfoEnabled then
			Target.LayoutInfo()
			return
		end
		local u = ensureUi()
		u.Name.Text = "Preview"
		u.User.Text = "@preview"
		u.Avatar.Image = ""
		u.Letter.Text = "P"
		u.Letter.Visible = true
		u.Hp.Text = "HP: 100 / 100"
		u.Fill.Size = UDim2.fromScale(1, 1)
		u.Scale.Scale = Settings.TargetInfoScale / 100
		if infoShown then
			Tween(u.Panel, TI.Fast, { Position = infoPos(false) })
		else
			infoShown = true
			Tween(u.Panel, TI.Medium, { Position = infoPos(false), GroupTransparency = 0 })
		end
		previewToken += 1
		local mine = previewToken
		task.delay(4, function()
			if mine == previewToken and not (Target.Current and Target.InfoEnabled) then
				hidePanel()
			end
		end)
	end

	-- ---- аура на цели. Стили: Constellation, Helix, Ghost Trail, Ring, Orbital Cube, Orbital, Swarm
	-- Каждый стиль добавляет свои обновлялки (updaters) и покраску (colorers); общий каркас - появление/исчезновение (Appear/Goal).
	local function buildAura(root)
		local aura = { Maid = Maid.new(), Appear = 0, Goal = 1, Root = root }
		local folder = Create("Folder", { Name = "NN_TargetAura", Parent = FxFolder })
		aura.Maid:Give(folder)
		local styles = { Settings.TargetStyle }
		if Target.MergeEnabled and Settings.TargetStyle2 ~= Settings.TargetStyle then
			styles[2] = Settings.TargetStyle2
		end
		local updaters, colorers = {}, {}

		local function newPart(props)
			local base = {
				Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Parent = folder,
			}
			for k, v in pairs(props) do
				base[k] = v
			end
			return Create("Part", base)
		end

		local function addTrail(part, life, half, startFade)
			local a0 = Create("Attachment", { Position = Vector3.new(0, half, 0), Parent = part })
			local a1 = Create("Attachment", { Position = Vector3.new(0, -half, 0), Parent = part })
			return Create("Trail", {
				Attachment0 = a0, Attachment1 = a1, Lifetime = life, MinLength = 0.02, FaceCamera = true,
				LightEmission = 1, LightInfluence = 0,
				Transparency = NS({ NSK(0, startFade or 0.1), NSK(1, 1) }),
				WidthScale = NS({ NSK(0, 1), NSK(0.6, 0.6), NSK(1, 0) }), Parent = part,
			})
		end

		local function setBall(part, size)
			size = math.max(size, 0.02)
			part.Size = Vector3.new(size, size, size)
		end

		for _, style in ipairs(styles) do
			-- ---- 1. Constellation: звёзды-точки вокруг цели, соединённые тонкими линиями (созвездие)
			if style == 1 then
				local N = 10
				local stars, beams = {}, {}
				for i = 1, N do
					local part = newPart({ Name = "Star" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22), Material = Enum.Material.Neon })
					stars[i] = {
						Part = part, Att = Create("Attachment", { Parent = part }), Seed = i * 1.7,
						Radius = 1.9 + (i % 3) * 0.45, Height = -2.4 + (i - 1) / (N - 1) * 4.8,
						Speed = (i % 2 == 0 and 1 or -1) * (0.26 + (i % 4) * 0.05),
					}
				end
				for i = 1, N do
					local links = { { i, i % N + 1 } }
					if i % 3 == 1 then
						links[2] = { i, (i + 2) % N + 1 }
					end
					for _, link in ipairs(links) do
						beams[#beams + 1] = Create("Beam", {
							Attachment0 = stars[link[1]].Att, Attachment1 = stars[link[2]].Att, FaceCamera = true, LightEmission = 1,
							LightInfluence = 0, Width0 = 0.05, Width1 = 0.05, Segments = 1,
							Transparency = NS({ NSK(0, 0.3), NSK(1, 0.3) }), Parent = stars[link[1]].Part,
						})
					end
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, s in ipairs(stars) do
						local th = t * s.Speed + s.Seed
						local r = s.Radius * ap
						local y = s.Height * ap + math.sin(t * 0.9 + s.Seed) * 0.35
						s.Part.CFrame = CFrame.new(center + Vector3.new(math.cos(th) * r, y, math.sin(th) * r))
						setBall(s.Part, (0.2 + 0.1 * (0.5 + 0.5 * math.sin(t * 3 + s.Seed * 2))) * ap)
					end
					for _, beam in ipairs(beams) do
						beam.Enabled = ap > 0.05
						beam.Width0 = 0.06 * ap
						beam.Width1 = 0.06 * ap
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for i, s in ipairs(stars) do
						s.Part.Color = (i % 2 == 0) and A or B
					end
					for _, beam in ipairs(beams) do
						beam.Color = ColorSequence.new(A, B)
					end
				end

			-- ---- 2. Helix: двойная спираль из светящихся шаров, плавно поднимающаяся вдоль тела
			elseif style == 2 then
				local N = 10
				local orbs = {}
				for strand = 0, 1 do
					for i = 1, N do
						local part = newPart({ Name = "Helix" .. strand .. "_" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), Material = Enum.Material.Neon })
						orbs[#orbs + 1] = { Part = part, Trail = addTrail(part, 0.28, 0.08, 0.15), Strand = strand, Index = i }
					end
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, o in ipairs(orbs) do
						local frac = ((o.Index - 1) / N + t * 0.16) % 1
						local th = t * 1.4 + frac * math.pi * 3 + o.Strand * math.pi
						local r = 1.7 * ap
						o.Part.CFrame = CFrame.new(center + Vector3.new(math.cos(th) * r, -3 + frac * 6.2, math.sin(th) * r))
						-- у краёв спирали шары гаснут, а на скачке с верха вниз след обрывается
						setBall(o.Part, (0.12 + 0.16 * math.sin(frac * math.pi)) * ap)
						o.Trail.Enabled = ap > 0.05 and frac > 0.04 and frac < 0.96
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for _, o in ipairs(orbs) do
						local c = o.Strand == 0 and A or B
						o.Part.Color = c
						o.Trail.Color = ColorSequence.new(c, o.Strand == 0 and B or A)
					end
				end

			-- ---- 3. Ghost Trail: призрачные огни с длинными мягкими шлейфами
			elseif style == 3 then
				local ghosts = {}
				for i = 1, 5 do
					local part = newPart({
						Name = "Ghost" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Material = Enum.Material.Neon, Transparency = 0.3,
					})
					ghosts[i] = {
						Part = part, Trail = addTrail(part, 0.95, 0.17, 0.25), Seed = i * 2.1,
						Speed = 0.55 + i * 0.08, Radius = 1.6 + (i % 3) * 0.5,
					}
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, g in ipairs(ghosts) do
						local th = t * g.Speed + g.Seed
						local r = g.Radius * ap
						g.Part.CFrame = CFrame.new(center + Vector3.new(
							math.cos(th) * r,
							math.sin(t * 0.7 + g.Seed) * 1.9 * ap + 0.2,
							math.sin(th + 0.6 * math.sin(t * 0.4 + g.Seed)) * r
						))
						g.Part.Transparency = math.clamp(0.25 + 0.2 * math.sin(t * 2 + g.Seed) + (1 - ap), 0, 1)
						setBall(g.Part, 0.4 * ap)
						g.Trail.Enabled = ap > 0.05
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for i, g in ipairs(ghosts) do
						local c = (i % 2 == 0) and A or B
						g.Part.Color = c
						g.Trail.Color = ColorSequence.new(c, (i % 2 == 0) and B or A)
					end
				end

			-- ---- 4. Ring: одно кольцо медленно и плавно скользит от ног к голове и обратно (+ два бледных следа)
			elseif style == 4 then
				local rings = {}
				for i = 1, 3 do
					local part = newPart({ Name = "Ring" .. i, Transparency = 1, Size = Vector3.new(4, 0.05, 4) })
					local strokes = {}
					for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
						local sg = Create("SurfaceGui", {
							Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(256, 256),
							LightInfluence = 0, Parent = part,
						})
						local stroke = Create("UIStroke", { Thickness = i == 1 and 9 or 6, Transparency = 1 })
						Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = sg }, { Corner(UDim.new(1, 0)), stroke })
						strokes[#strokes + 1] = stroke
					end
					-- Lag: отставание следа по времени; Mul: насколько он прозрачнее главного кольца
					rings[i] = { Part = part, Strokes = strokes, Lag = (i - 1) * 0.35, Mul = ({ 0.9, 0.35, 0.16 })[i] }
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, ring in ipairs(rings) do
						local s = 0.5 + 0.5 * math.sin((t - ring.Lag) * 0.75) -- медленное движение
						s = s * s * (3 - 2 * s)
						local size = math.max(3.6 * ap * (0.94 + 0.06 * math.sin(t * 1.6 - ring.Lag)), 0.1)
						ring.Part.Size = Vector3.new(size, 0.05, size)
						ring.Part.CFrame = CFrame.new(center.X, center.Y - 3 + s * 5.4, center.Z)
						for _, stroke in ipairs(ring.Strokes) do
							stroke.Transparency = 1 - ap * ring.Mul
						end
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for i, ring in ipairs(rings) do
						for _, stroke in ipairs(ring.Strokes) do
							stroke.Color = (i == 1) and A or B
						end
					end
				end

			-- ---- 5. Orbital Cube: неоновые кубики вращаются вокруг игрока
			elseif style == 5 then
				local cubes = {}
				for i = 1, 6 do
					local part = newPart({ Name = "Cube" .. i, Size = Vector3.new(0.5, 0.5, 0.5), Material = Enum.Material.Neon, Transparency = 0.12 })
					-- шлейф живёт на отдельной невращающейся детали, чтобы лента не "мигала"
					local tail = newPart({ Name = "CubeTail" .. i, Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) })
					cubes[i] = {
						Part = part, Tail = tail, Trail = addTrail(tail, 0.35, 0.16, 0.2), Phase = (i - 1) * math.pi / 3,
						Height = ({ 1.4, -0.6, 0.7, -1.5, 0.1, -0.2 })[i],
					}
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, c in ipairs(cubes) do
						local th = t * 1.35 + c.Phase
						local r = 2.6 * ap
						local pos = center + Vector3.new(math.cos(th) * r, c.Height + math.sin(t * 1.5 + c.Phase) * 0.3, math.sin(th) * r)
						local size = 0.5 * ap
						c.Part.Size = Vector3.new(math.max(size, 0.02), math.max(size, 0.02), math.max(size, 0.02))
						c.Part.CFrame = CFrame.new(pos) * CFrame.Angles(t * 1.8 + c.Phase, t * 1.2, t * 0.9)
						c.Tail.CFrame = CFrame.new(pos)
						c.Trail.Enabled = ap > 0.05
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for i, c in ipairs(cubes) do
						local col = (i % 2 == 0) and A or B
						c.Part.Color = col
						c.Trail.Color = ColorSequence.new(col, (i % 2 == 0) and B or A)
					end
				end

			-- ---- 6. Orbital: обычная орбитальная аура - четыре ленты-дуги по кругу
			elseif style == 6 then
				local arcs = {}
				for i = 1, 4 do
					local part = newPart({ Name = "Arc" .. i, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
					local trail = addTrail(part, 0.55, 0.45, 0.1)
					arcs[i] = { Part = part, Trail = trail, Phase = (i - 1) * math.pi / 2, Height = ({ 1.2, -0.2, 0.6, -0.9 })[i] }
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, arc in ipairs(arcs) do
						local theta = t * 2.4 + arc.Phase
						local r = 2.5 * ap
						arc.Part.CFrame = CFrame.new(center + Vector3.new(math.cos(theta) * r, arc.Height + math.sin(t * 1.7 + arc.Phase) * 0.25, math.sin(theta) * r))
						arc.Trail.Enabled = ap > 0.05
					end
				end
				colorers[#colorers + 1] = function()
					for _, arc in ipairs(arcs) do
						arc.Trail.Color = Palette.Sequence()
					end
				end

			-- ---- 7. Swarm: яркие искры с короткими полосами по плавным хаотичным траекториям
			else
				local swarm = {}
				for i = 1, 18 do
					local part = newPart({ Name = "Spark" .. i, Shape = Enum.PartType.Ball, Size = Vector3.new(0.16, 0.16, 0.16), Material = Enum.Material.Neon })
					swarm[i] = {
						Part = part, Trail = addTrail(part, 0.35, 0.06, 0), Seed = math.random() * 100,
						Speed = 1.2 + math.random() * 1.8, Radius = 1.4 + math.random() * 1.8,
					}
				end
				updaters[#updaters + 1] = function(ap, t, center)
					for _, spark in ipairs(swarm) do
						local tt = t * spark.Speed + spark.Seed
						local r = spark.Radius * ap
						spark.Part.CFrame = CFrame.new(center + Vector3.new(
							math.cos(tt) * r + math.sin(tt * 1.7) * 0.6 * ap,
							math.sin(tt * 1.3) * 2.0 * ap + 0.2,
							math.sin(tt * 0.9 + 1) * r
						))
						spark.Trail.Enabled = ap > 0.05
					end
				end
				colorers[#colorers + 1] = function(A, B)
					for i, spark in ipairs(swarm) do
						local c = (i % 2 == 0) and A or B
						spark.Part.Color = c
						spark.Trail.Color = ColorSequence.new(c, (i % 2 == 0) and B or A)
					end
				end
			end
		end

		function aura.Colors()
			local A, B = Palette.GetColors()
			for _, fn in ipairs(colorers) do
				fn(A, B)
			end
		end
		aura.Colors()

		function aura.Update(dt, t)
			aura.Appear += (aura.Goal - aura.Appear) * ExpAlpha(14, dt)
			local ap = aura.Appear
			local center = root.Position
			for _, fn in ipairs(updaters) do
				fn(ap, t, center)
			end
		end

		aura.Maid:Give(Palette.Changed.Event:Connect(aura.Colors))
		return aura
	end

	local function releaseTarget()
		if Target.Current then
			for _, aura in ipairs(Target.Auras) do
				aura.Goal = 0
			end
			hidePanel()
			Target.Current = nil
		end
	end

	local function applyTarget(cand)
		releaseTarget()
		Target.Current = cand
		Target.Char = cand.Model
		if Target.AuraEnabled then
			Target.Auras[#Target.Auras + 1] = buildAura(cand.Root)
		end
		if Target.InfoEnabled then
			showPanel(cand)
		end
	end

	-- ---- поиск цели
	local function watchRigs()
		for _, d in ipairs(Workspace:GetDescendants()) do
			if d:IsA("Humanoid") then
				rigs[d] = true
			end
		end
		maid:Give(Workspace.DescendantAdded:Connect(function(d)
			if d:IsA("Humanoid") then
				rigs[d] = true
			end
		end))
		maid:Give(Workspace.DescendantRemoving:Connect(function(d)
			if d:IsA("Humanoid") then
				rigs[d] = nil
			end
		end))
	end

	local function gather()
		local list = {}
		local own = LocalPlayer.Character
		for _, p in ipairs(Players:GetPlayers()) do
			local c = p.Character
			if p ~= LocalPlayer and c then
				local hum, root = c:FindFirstChildOfClass("Humanoid"), c:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					list[#list + 1] = { Model = c, Player = p, Humanoid = hum, Root = root }
				end
			end
		end
		if Target.RigsEnabled then
			for hum in pairs(rigs) do
				local model = hum.Parent
				if model and model:IsA("Model") and model ~= own and hum.Health > 0 and not Players:GetPlayerFromCharacter(model) then
					local root = model:FindFirstChild("HumanoidRootPart")
					if root then
						list[#list + 1] = { Model = model, Humanoid = hum, Root = root }
					end
				end
			end
		end
		return list
	end

	local function visible(cam, cand, point)
		local origin = cam.CFrame.Position
		local ignore = { FxFolder }
		if LocalPlayer.Character then
			ignore[2] = LocalPlayer.Character
		end
		for _ = 1, 4 do
			rayParams.FilterDescendantsInstances = ignore
			rayParams.RespectCanCollide = false
			local result = Workspace:Raycast(origin, point - origin, rayParams)
			if not result then
				return true
			end
			if result.Instance:IsDescendantOf(cand.Model) then
				return true
			end
			if result.Instance.Transparency >= 0.95 then
				ignore[#ignore + 1] = result.Instance -- невидимая деталь: смотрим сквозь неё
			else
				return false
			end
		end
		return false
	end

	local function detect()
		local cam = GetCamera()
		if not cam then
			return nil
		end
		local vp = cam.ViewportSize
		local pointer = vp / 2 -- прицел таргета всегда в центре экрана (на ПК и на телефоне)
		-- радиус зоны = доля от половины высоты экрана (настраивается кружком в калибровке)
		local radius = vp.Y / 2 * Settings.TargetFov / 100

		local camPos = cam.CFrame.Position
		local scored = {}
		for _, cand in ipairs(gather()) do
			local rp = cand.Root.Position
			if (rp - camPos).Magnitude <= Settings.TargetRange then
				local bestDist, bestPoint = math.huge, rp
				for _, offset in ipairs({ 0, 2.4, -2.4 }) do
					local p = rp + Vector3.new(0, offset, 0)
					local sp = cam:WorldToViewportPoint(p)
					if sp.Z > 0 then
						local d = (Vector2.new(sp.X, sp.Y) - pointer).Magnitude
						if d < bestDist then
							bestDist, bestPoint = d, p
						end
					end
				end
				-- текущая цель "липкая": ей проще удержаться в прицеле
				if Target.Current and Target.Current.Model == cand.Model then
					bestDist *= 0.65
				end
				if bestDist <= radius then
					cand.Point = bestPoint
					cand.Score = bestDist
					scored[#scored + 1] = cand
				end
			end
		end
		table.sort(scored, function(a, b)
			return a.Score < b.Score
		end)
		for i = 1, math.min(#scored, 3) do
			if visible(cam, scored[i], scored[i].Point) then
				return scored[i]
			end
		end
		return nil
	end

	function Target.Start()
		if Target.Running then
			return
		end
		Target.Running = true
		maid = Maid.new()
		watchRigs()
		maid:Give(RunService.Heartbeat:Connect(function(dt)
			step += dt
			if step < 0.033 then
				return
			end
			local elapsed = step
			step = 0
			local cand = detect()
			if cand then
				loseTimer = 0
				if not Target.Current or cand.Model ~= Target.Current.Model then
					applyTarget(cand)
				end
			else
				loseTimer += elapsed
				if loseTimer > 0.12 then
					releaseTarget()
				end
			end
			if Target.Current and not Target.Current.Model.Parent then
				releaseTarget()
			end
		end))
		maid:Give(RunService.RenderStepped:Connect(function(dt)
			local t = os.clock()
			for i = #Target.Auras, 1, -1 do
				local aura = Target.Auras[i]
				if aura.Root.Parent then
					aura.Update(dt, t)
				else
					aura.Goal = 0
				end
				if aura.Goal == 0 and aura.Appear < 0.03 then
					aura.Maid:Clean()
					table.remove(Target.Auras, i)
				end
			end
			local cur = Target.Current
			if cur and ui and Target.InfoEnabled and cur.Humanoid.Parent then
				local hum = cur.Humanoid
				local ratio = hum.MaxHealth > 0 and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 0
				hpSmooth += (ratio - hpSmooth) * ExpAlpha(12, dt)
				ui.Fill.Size = UDim2.fromScale(hpSmooth, 1)
				ui.Fill.BackgroundColor3 = ratio < CONFIG.LowHpThreshold and THEME.Error or THEME.SwitchOn
				ui.Hp.Text = string.format("HP: %d / %d", math.floor(hum.Health + 0.5), math.floor(hum.MaxHealth + 0.5))
			end
		end))
	end

	--- Перестроить эффекты для текущей цели (после смены флагов или стиля)
	function Target.Refresh()
		local cand = Target.Current
		if not cand or not cand.Model.Parent then
			return
		end
		applyTarget(cand)
	end

	function Target.StopIfIdle()
		if Target.AuraEnabled or Target.InfoEnabled or not Target.Running then
			return
		end
		Target.Running = false
		releaseTarget()
		for _, aura in ipairs(Target.Auras) do
			aura.Maid:Clean()
		end
		Target.Auras = {}
		rigs = {}
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	function Target.Destroy()
		Target.AuraEnabled, Target.InfoEnabled = false, false
		Target.StopIfIdle()
		if ui then
			ui.Panel:Destroy()
			ui = nil
		end
	end
end

Modules.TargetAura = {
	Enable = function()
		Target.AuraEnabled = true
		Target.Start()
		Target.Refresh()
	end,
	Disable = function()
		Target.AuraEnabled = false
		Target.Refresh()
		Target.StopIfIdle()
	end,
}

--- Объединение двух стилей: аура рисует сразу два выбранных стиля
Modules.TargetMerge = {
	Enable = function()
		Target.MergeEnabled = true
		Target.Refresh()
	end,
	Disable = function()
		Target.MergeEnabled = false
		Target.Refresh()
	end,
}

Modules.TargetInfo = {
	Enable = function()
		Target.InfoEnabled = true
		Target.Start()
		Target.Refresh()
	end,
	Disable = function()
		Target.InfoEnabled = false
		Target.Refresh()
		Target.StopIfIdle()
	end,
}

--- Включает поддержку ботов и обычных Rig (нужен гуманоид и HumanoidRootPart)
Modules.TargetRigs = {
	Enable = function()
		Target.RigsEnabled = true
	end,
	Disable = function()
		Target.RigsEnabled = false
	end,
}

-- ----------------------------------------------------------------------------
-- 8.11 DeathFX: эффекты смерти (молния + разрыв, распад на частицы) для себя и других игроков
-- ----------------------------------------------------------------------------
local DeathFx = {}

do
	local LIGHTNING_TIME = 1.5

	local function bodyParts(char)
		local parts, decals = {}, {}
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
				parts[#parts + 1] = d
			elseif d:IsA("Decal") then
				decals[#decals + 1] = d
			end
		end
		return parts, decals
	end

	--- Локальное растворение тела. delays[part] - задержка старта (для "распада" по частям)
	local function dissolve(parts, decals, duration, delays, restoreAfter)
		local start = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local elapsed = os.clock() - start
			local done = true
			for _, p in ipairs(parts) do
				if p.Parent then
					local d = delays and delays[p] or 0
					local a = math.clamp((elapsed - d) / duration, 0, 1)
					p.LocalTransparencyModifier = a
					if a < 1 then
						done = false
					end
				end
			end
			for _, d in ipairs(decals) do
				if d.Parent then
					pcall(function()
						d.LocalTransparencyModifier = math.clamp(elapsed / duration, 0, 1)
					end)
				end
			end
			if done and elapsed > duration then
				conn:Disconnect()
			end
		end)
		if restoreAfter then
			task.delay(restoreAfter, function()
				conn:Disconnect()
				for _, p in ipairs(parts) do
					if p.Parent then
						p.LocalTransparencyModifier = 0
					end
				end
				for _, d in ipairs(decals) do
					if d.Parent then
						pcall(function()
							d.LocalTransparencyModifier = 0
						end)
					end
				end
			end)
		end
	end

	-- ---- молния (белая сердцевина + цветное свечение, ветвление, мерцание)
	function DeathFx.Strike(position)
		local A = Palette.GetColors()
		local top = position + Vector3.new(math.random(-6, 6), 70, math.random(-6, 6))
		local holder = Create("Part", {
			Name = "NN_Lightning", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Parent = FxFolder,
		})
		local beams = {}
		local function bolt(from, to, segments, width, roughness)
			local points = { from }
			for i = 1, segments - 1 do
				local a = i / segments
				local jitter = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * roughness * (1 - a * 0.6)
				points[#points + 1] = from + (to - from) * a + jitter
			end
			points[#points + 1] = to
			local atts = {}
			for i, p in ipairs(points) do
				atts[i] = Create("Attachment", { Parent = holder })
				atts[i].WorldPosition = p
			end
			for i = 1, #atts - 1 do
				beams[#beams + 1] = { Base = 0, Beam = Create("Beam", {
					Attachment0 = atts[i], Attachment1 = atts[i + 1], Width0 = width, Width1 = width, Segments = 1,
					LightEmission = 1, LightInfluence = 0, FaceCamera = true, Color = ColorSequence.new(Color3.new(1, 1, 1)), Parent = holder,
				}) }
				beams[#beams + 1] = { Base = 0.55, Beam = Create("Beam", {
					Attachment0 = atts[i], Attachment1 = atts[i + 1], Width0 = width * 4, Width1 = width * 4, Segments = 1,
					LightEmission = 1, LightInfluence = 0, FaceCamera = true, Color = ColorSequence.new(A), Parent = holder,
				}) }
			end
			return points
		end
		local main = bolt(top, position, 14, 0.45, 9)
		for _ = 1, 3 do
			local origin = main[math.random(3, #main - 3)]
			local dir = Vector3.new(math.random(-10, 10), -math.random(8, 16), math.random(-10, 10))
			bolt(origin, origin + dir, 5, 0.25, 4)
		end
		local light = Create("PointLight", { Range = 45, Brightness = 10, Color = A:Lerp(Color3.new(1, 1, 1), 0.5), Parent = holder })
		Modules.HitFX.Burst(position, Vector3.yAxis, 1.6)

		local cam = GetCamera()
		local dist = cam and (cam.CFrame.Position - position).Magnitude or 999
		if dist < 80 then
			Modules.ScreenShake.Shake(math.clamp(1.2 - dist / 80, 0.2, 1), 0.6, { Mode = "noise", Frequency = 30 })
		end

		local start = os.clock()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local t = (os.clock() - start) / LIGHTNING_TIME
			if t >= 1 or not holder.Parent then
				conn:Disconnect()
				holder:Destroy()
				return
			end
			local flicker = (math.random() < 0.35) and 0.65 or 0
			local fade = t ^ 2.2
			for _, item in ipairs(beams) do
				item.Beam.Transparency = NS(math.clamp(item.Base + fade + flicker, 0, 1))
			end
			light.Brightness = 10 * (1 - t) * (flicker > 0 and 0.4 or 1)
		end)
	end

	-- ---- разрыв на частицы (текстура из CONFIG.DeathParticleTexture)
	function DeathFx.Shatter(char, rootCF)
		local parts, decals = bodyParts(char)
		for _, part in ipairs(parts) do
			local s = part.Size
			local volume = s.X * s.Y * s.Z
			local e = Create("ParticleEmitter", {
				Rate = 0, Texture = CONFIG.DeathParticleTexture, Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(6, 22), SpreadAngle = Vector2.new(180, 180),
				Drag = 1.2, Acceleration = Vector3.new(0, -18, 0), LightEmission = 0.6, LightInfluence = 0,
				Size = NS({ NSK(0, 1.1), NSK(1, 0) }), Transparency = NS({ NSK(0, 0), NSK(0.7, 0.3), NSK(1, 1) }),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120), Parent = part,
			})
			e:Emit(math.clamp(math.floor(volume * 4), 4, 28))
			local sparkle = Create("ParticleEmitter", {
				Rate = 0, Color = Palette.Sequence(), Lifetime = NumberRange.new(0.5, 1.1), Speed = NumberRange.new(8, 26),
				SpreadAngle = Vector2.new(180, 180), Drag = 1.5, Acceleration = Vector3.new(0, -12, 0),
				LightEmission = 1, LightInfluence = 0, Size = NS({ NSK(0, 0.5), NSK(1, 0) }),
				Transparency = NS({ NSK(0, 0), NSK(1, 1) }), Parent = part,
			})
			sparkle:Emit(math.clamp(math.floor(volume * 2), 2, 14))
			Debris:AddItem(e, 2.5)
			Debris:AddItem(sparkle, 2.5)
		end
		local cloud = Create("Part", {
			Name = "NN_DeathCloud", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(3, 5.5, 1.6), CFrame = rootCF, Parent = FxFolder,
		})
		local ce = Create("ParticleEmitter", {
			Rate = 0, Texture = CONFIG.DeathParticleTexture, Lifetime = NumberRange.new(0.9, 1.7), Speed = NumberRange.new(5, 20),
			SpreadAngle = Vector2.new(180, 180), Drag = 1, Acceleration = Vector3.new(0, -16, 0),
			Size = NS({ NSK(0, 1.2), NSK(1, 0) }), Transparency = NS({ NSK(0, 0), NSK(0.7, 0.3), NSK(1, 1) }),
			LightEmission = 0.6, LightInfluence = 0, Parent = cloud,
		})
		ce:Emit(50)
		Debris:AddItem(cloud, 3)
		dissolve(parts, decals, 0.35, nil, nil)
	end

	-- ---- распад на частицы без молнии: основа - 3D-взрыв удара, тело рассыпается по частям
	function DeathFx.Decay(char, rootCF, restoreAfter)
		local position = rootCF.Position
		Modules.HitFX.Burst(position, Vector3.yAxis, 1.3)

		local parts, decals = bodyParts(char)
		local delays = {}
		for _, part in ipairs(parts) do
			delays[part] = math.random() * 0.5
			local s = part.Size
			local volume = s.X * s.Y * s.Z
			local dust = Create("ParticleEmitter", {
				Rate = 0, Color = Palette.Sequence(), Lifetime = NumberRange.new(0.9, 1.6), Speed = NumberRange.new(2, 9),
				SpreadAngle = Vector2.new(180, 180), Drag = 2, Acceleration = Vector3.new(0, 6, 0), -- частицы уплывают вверх
				LightEmission = 1, LightInfluence = 0, Size = NS({ NSK(0, 0.45), NSK(1, 0) }),
				Transparency = NS({ NSK(0, 0), NSK(0.6, 0.2), NSK(1, 1) }),
				Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90), Parent = part,
			})
			-- эмиссия растянута во времени вместе с растворением части
			task.delay(delays[part], function()
				if dust.Parent then
					dust:Emit(math.clamp(math.floor(volume * 6), 5, 36))
				end
			end)
			Debris:AddItem(dust, 3)
		end
		dissolve(parts, decals, 0.5, delays, restoreAfter)
	end
end

local function makeDeathModule(handler)
	local M = {}
	local maid

	local function shouldPlay(player)
		local mode = Settings.DeathTargets
		if mode == 2 then
			return player == LocalPlayer
		elseif mode == 3 then
			return player ~= LocalPlayer
		end
		return true
	end

	local function hookCharacter(player, char, cmaid)
		local humanoid = char:WaitForChild("Humanoid", 10)
		if not humanoid then
			return
		end
		local fired = false
		local function onDeath()
			if fired or not shouldPlay(player) then
				return
			end
			fired = true
			-- позиция берётся по корню рига (HumanoidRootPart / Humanoid.RootPart)
			local root = humanoid.RootPart or char:FindFirstChild("HumanoidRootPart")
			local cf = root and root.CFrame or CFrame.new(char:GetPivot().Position)
			handler(char, cf)
		end
		cmaid:Give(humanoid.Died:Connect(onDeath))
		cmaid:Give(humanoid.HealthChanged:Connect(function(health)
			if health <= 0 then
				onDeath()
			end
		end))
	end

	local function hookPlayer(player)
		local pmaid = Maid.new()
		maid:Give(pmaid)
		local cmaid = Maid.new()
		pmaid:Give(cmaid)
		local function attach(char)
			cmaid:Clean()
			task.spawn(hookCharacter, player, char, cmaid)
		end
		if player.Character then
			attach(player.Character)
		end
		pmaid:Give(player.CharacterAdded:Connect(attach))
	end

	function M.Enable()
		maid = Maid.new()
		for _, player in ipairs(Players:GetPlayers()) do
			hookPlayer(player)
		end
		maid:Give(Players.PlayerAdded:Connect(hookPlayer))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end

Modules.DeathFX = makeDeathModule(function(char, cf)
	DeathFx.Strike(cf.Position)
	DeathFx.Shatter(char, cf)
end)

Modules.DeathDecay = makeDeathModule(function(char, cf)
	DeathFx.Decay(char, cf, nil)
end)

-- ---- DeathSound: звук смерти игрока (заменяет стоковые звуки молнии и распада)
do
	local function playDeathSound(position, mine)
		local entry = DEATH_SOUNDS[Settings.DeathSound] or DEATH_SOUNDS[1]
		local volume = Settings.DeathVolume / 100
		if not mine then
			-- чужая смерть: чем дальше, тем тише
			local cam = GetCamera()
			local dist = cam and (cam.CFrame.Position - position).Magnitude or 0
			volume = volume * math.clamp(1 - dist / 260, 0.15, 1)
		end
		PlayAsset(entry.Id, volume, 8)
	end
	Modules.DeathSound = makeDeathModule(function(char, cf)
		playDeathSound(cf.Position, char == LocalPlayer.Character)
	end)
end

-- ---- HitSound: звук попадания. Срабатывает, когда:
--   * у другого игрока или бота отнялось HP (режимы "HP + логи" и "Цель в прицеле"),
--   * в логах (LogService) найден урон от вас (режимы "HP + логи" и "Только логи"),
--   * у получившего урон Humanoid стоит тег "creator" с вашим игроком (любой режим).
do
	local LogService = game:GetService("LogService")
	-- слова из логов, означающие урон; ник должен стоять РАНЬШЕ такого слова (или после "by "), иначе это урон по вам
	local HIT_KEYWORDS = { "damage", "dmg", "hit", "hurt", "урон", "попал", "удар" }
	local lastPlay = { hp = -10, log = -10 }
	local maid
	local hooked = {}

	local function playHit(source)
		local now = os.clock()
		local other = source == "hp" and "log" or "hp"
		if now - lastPlay[source] < 0.06 then
			return
		end
		-- один и тот же удар не должен играть дважды: HP и лог приходят почти одновременно
		if now - lastPlay[other] < 0.35 then
			return
		end
		lastPlay[source] = now
		local entry = HIT_SOUNDS[Settings.HitSound] or HIT_SOUNDS[1]
		PlayAsset(entry.Id, Settings.HitVolume / 100, 4)
	end

	local function isMyHit(text)
		local low = string.lower(text)
		local firstKey = nil
		for _, key in ipairs(HIT_KEYWORDS) do
			local p = string.find(low, key, 1, true)
			if p and (not firstKey or p < firstKey) then
				firstKey = p
			end
		end
		if not firstKey then
			return false
		end
		for _, name in ipairs({ LocalPlayer.Name, LocalPlayer.DisplayName }) do
			if name ~= "" then
				local lowName = string.lower(name)
				local p = string.find(text, name, 1, true) or string.find(low, lowName, 1, true)
				if p and p < firstKey then
					return true
				end
				if string.find(low, "by " .. lowName, 1, true) then
					return true
				end
			end
		end
		return false
	end

	--- Цель в зоне прицела (размер зоны берётся из калибровки "Зона таргета")
	local function isAimed(root)
		local cam = GetCamera()
		if not cam then
			return false
		end
		local dir = root.Position - cam.CFrame.Position
		if dir.Magnitude < 0.1 then
			return true
		end
		local cosA = math.clamp(cam.CFrame.LookVector:Dot(dir.Unit), -1, 1)
		local limit = math.max(cam.FieldOfView * Settings.TargetFov / 200, 6)
		return math.deg(math.acos(cosA)) <= limit
	end

	local function onDamaged(humanoid)
		local char = humanoid.Parent
		if not char or char == LocalPlayer.Character then
			return
		end
		local tag = humanoid:FindFirstChild("creator")
		if tag and tag:IsA("ObjectValue") and tag.Value == LocalPlayer then
			playHit("hp")
			return
		end
		if Settings.HitMode == 3 then
			return
		end
		local root = humanoid.RootPart or char:FindFirstChild("HumanoidRootPart")
		local mine = GetRoot()
		if not root or not mine then
			return
		end
		if (root.Position - mine.Position).Magnitude > Settings.HitRange then
			return
		end
		if Settings.HitMode == 1 or isAimed(root) then
			playHit("hp")
		end
	end

	local function hookHumanoid(humanoid)
		if hooked[humanoid] then
			return
		end
		local last = humanoid.Health
		hooked[humanoid] = humanoid.HealthChanged:Connect(function(health)
			local dropped = last - health
			last = health
			if dropped > 0.01 then
				onDamaged(humanoid)
			end
		end)
	end

	local function unhookHumanoid(humanoid)
		local conn = hooked[humanoid]
		if conn then
			conn:Disconnect()
			hooked[humanoid] = nil
		end
	end

	Modules.HitSound = {
		Enable = function()
			maid = Maid.new()
			maid:Give(LogService.MessageOut:Connect(function(message)
				if Settings.HitMode ~= 2 and type(message) == "string" and isMyHit(message) then
					playHit("log")
				end
			end))
			for _, d in ipairs(Workspace:GetDescendants()) do
				if d:IsA("Humanoid") then
					hookHumanoid(d)
				end
			end
			maid:Give(Workspace.DescendantAdded:Connect(function(d)
				if d:IsA("Humanoid") then
					hookHumanoid(d)
				end
			end))
			maid:Give(Workspace.DescendantRemoving:Connect(function(d)
				if d:IsA("Humanoid") then
					unhookHumanoid(d)
				end
			end))
			maid:Give(function()
				for _, conn in pairs(hooked) do
					conn:Disconnect()
				end
				hooked = {}
			end)
		end,
		Disable = function()
			if maid then
				maid:Clean()
				maid = nil
			end
		end,
	}
end

function DeathFx.TestLightning()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		DeathFx.Strike(root.Position + root.CFrame.LookVector * 12)
	end
end

function DeathFx.TestDecay()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		DeathFx.Decay(char, root.CFrame, 2.6) -- на тесте тело возвращается через 2.6 с
	end
end

-- ----------------------------------------------------------------------------
-- 8.11b AntiFling: защита от выбрасывания за карту (коллизии с чужими + гашение импульса)
-- ----------------------------------------------------------------------------
Modules.AntiFling = (function()
	local M = {}
	local maid
	local cache, changed = {}, {}

	local function track(player)
		local function attach(char)
			local list = {}
			cache[char] = list
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") then
					list[#list + 1] = d
				end
			end
			maid:Give(char.DescendantAdded:Connect(function(d)
				if d:IsA("BasePart") then
					list[#list + 1] = d
				end
			end))
		end
		if player.Character then
			attach(player.Character)
		end
		maid:Give(player.CharacterAdded:Connect(attach))
		maid:Give(player.CharacterRemoving:Connect(function(char)
			cache[char] = nil
		end))
	end

	function M.Enable()
		maid = Maid.new()
		cache, changed = {}, {}
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer then
				track(player)
			end
		end
		maid:Give(Players.PlayerAdded:Connect(function(player)
			if player ~= LocalPlayer then
				track(player)
			end
		end))

		-- 1) локально отключаем столкновения с телами других игроков
		maid:Give(RunService.Stepped:Connect(function()
			for _, list in pairs(cache) do
				for i = #list, 1, -1 do
					local p = list[i]
					if p.Parent then
						if p.CanCollide then
							p.CanCollide = false
							changed[p] = true
						end
					else
						table.remove(list, i)
					end
				end
			end
		end))

		-- 2) гасим аномальный импульс на своём персонаже и возвращаем на последнюю безопасную точку
		BindCharacter(maid, function(char, cmaid, isAlive)
			local humanoid = char:WaitForChild("Humanoid", 10)
			local root = char:WaitForChild("HumanoidRootPart", 10)
			if not humanoid or not root or not isAlive() then
				return
			end
			local lastSafe = root.CFrame
			local flungUntil, lastWarn = 0, 0
			cmaid:Give(RunService.Heartbeat:Connect(function()
				if humanoid.Health <= 0 or not root.Parent then
					return
				end
				local now = os.clock()
				local vel, ang = root.AssemblyLinearVelocity, root.AssemblyAngularVelocity
				if humanoid.FloorMaterial ~= Enum.Material.Air and vel.Magnitude < 40 and ang.Magnitude < 20 then
					lastSafe = root.CFrame
				end
				if vel.Magnitude > CONFIG.AntiFlingSpeed or ang.Magnitude > CONFIG.AntiFlingSpin then
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
					flungUntil = now + 2
					if now - lastWarn > 4 then
						lastWarn = now
						Notify.Info(T("Опасный импульс погашен."), "Anti Fling", 3, true)
					end
				end
				if now < flungUntil then
					local outside = root.Position.Y < Workspace.FallenPartsDestroyHeight + 40
						or (root.Position - lastSafe.Position).Magnitude > 350
					if outside then
						root.AssemblyLinearVelocity = Vector3.zero
						root.AssemblyAngularVelocity = Vector3.zero
						root.CFrame = lastSafe + Vector3.new(0, 3, 0)
						flungUntil = 0
					end
				end
			end))
		end)
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		for p in pairs(changed) do
			if p.Parent then
				p.CanCollide = true
			end
		end
		cache, changed = {}, {}
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11c Rain: тихий быстрый дождь со звуком (в помещении звук тише, капли не идут)
-- ----------------------------------------------------------------------------
Modules.Rain = (function()
	local M = {}
	local maid, sound

	function M.Enable()
		maid = Maid.new()
		local anchor = Create("Part", {
			Name = "NN_Rain", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, Size = Vector3.new(110, 1, 110), Parent = FxFolder,
		})
		maid:Give(anchor)
		local emitter = Create("ParticleEmitter", {
			Name = "Rain",
			Texture = CONFIG.RainTexture,
			Color = ColorSequence.new(Color3.fromRGB(190, 210, 240)),
			LightEmission = 0.15,
			LightInfluence = 0.4,
			Orientation = Enum.ParticleOrientation.VelocityParallel, -- капля вытянута вдоль падения
			Size = NS({ NSK(0, 0.22, 0.06), NSK(1, 0.22, 0.06) }),
			Squash = NS(CONFIG.RainSquash),
			Transparency = NS({ NSK(0, 1), NSK(0.08, 0.55), NSK(0.9, 0.55), NSK(1, 1) }), -- тонкий, спокойный дождь
			Lifetime = NumberRange.new(0.9, 1.1),
			Rate = 520,
			Speed = NumberRange.new(70, 85), -- быстрые капли
			SpreadAngle = Vector2.new(1, 1),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(-4, 0, 0),
			LockedToPart = false,
			Parent = anchor,
		})

		-- зацикленный тихий звук с плавным появлением
		sound = Create("Sound", {
			Name = "NN_RainLoop", SoundId = "rbxassetid://" .. tostring(SOUND_IDS.Rain), Looped = true, Volume = 0, Parent = SoundService,
		})
		sound:Play()
		local mine = sound
		Tween(mine, TI.Slow, { Volume = 0.22 })

		local timer = 0
		maid:Give(RunService.RenderStepped:Connect(function(dt)
			local cam = GetCamera()
			if not cam then
				return
			end
			local camPos = cam.CFrame.Position
			anchor.CFrame = CFrame.new(camPos + Vector3.new(0, 40, 0))
			timer += dt
			if timer > 0.3 then
				timer = 0
				local roof = Raycast(camPos, Vector3.new(0, 70, 0), LocalPlayer.Character, true)
				emitter.Enabled = roof == nil
				if mine.Parent then
					Tween(mine, TI.Medium, { Volume = roof and 0.08 or 0.22 }) -- под крышей звук тише
				end
			end
		end))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
		if sound then
			local s = sound
			sound = nil
			Tween(s, TI.Medium, { Volume = 0 })
			Debris:AddItem(s, 0.8)
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11d Potato: режим картошки - локально убирает текстуры и тени для оптимизации.
-- Не сохраняется в конфигах. Всё возвращается при выключении.
-- ----------------------------------------------------------------------------
Modules.Potato = (function()
	local M = {}
	local maid
	local token = 0
	local saved = setmetatable({}, { __mode = "k" })
	local envSaved = {}

	local function strip(inst)
		if inst:IsDescendantOf(FxFolder) then
			return -- наши эффекты не трогаем
		end
		pcall(function()
			if inst:IsA("BasePart") then
				local s = saved[inst]
				if not s then
					s = { Material = inst.Material, Reflectance = inst.Reflectance, CastShadow = inst.CastShadow }
					saved[inst] = s
				end
				inst.Material = Enum.Material.SmoothPlastic
				inst.Reflectance = 0
				inst.CastShadow = false
				if inst:IsA("MeshPart") and inst.TextureID ~= "" then
					s.TextureID = s.TextureID or inst.TextureID
					inst.TextureID = ""
				end
			elseif inst:IsA("Decal") or inst:IsA("Texture") then
				if not saved[inst] then
					saved[inst] = { Transparency = inst.Transparency }
				end
				inst.Transparency = 1
			elseif inst:IsA("SurfaceAppearance") then
				saved[inst] = { Parent = inst.Parent }
				inst.Parent = nil
			end
		end)
	end

	function M.Enable()
		token += 1
		local mine = token
		maid = Maid.new()
		envSaved = { GlobalShadows = Lighting.GlobalShadows }
		Lighting.GlobalShadows = false
		for prop, value in pairs({ WaterWaveSize = 0, WaterReflectance = 0, Decoration = false }) do
			pcall(function()
				envSaved[prop] = Workspace.Terrain[prop]
				Workspace.Terrain[prop] = value
			end)
		end
		maid:Give(Workspace.DescendantAdded:Connect(strip))
		task.spawn(function()
			local list = Workspace:GetDescendants()
			for i, inst in ipairs(list) do
				if token ~= mine then
					return
				end
				strip(inst)
				if i % 300 == 0 then
					task.wait() -- обработка пачками, чтобы не подвесить игру
				end
			end
		end)
	end

	function M.Disable()
		token += 1
		if maid then
			maid:Clean()
			maid = nil
		end
		pcall(function()
			Lighting.GlobalShadows = envSaved.GlobalShadows
		end)
		for _, prop in ipairs({ "WaterWaveSize", "WaterReflectance", "Decoration" }) do
			if envSaved[prop] ~= nil then
				pcall(function()
					Workspace.Terrain[prop] = envSaved[prop]
				end)
			end
		end
		envSaved = {}
		local list = {}
		for inst, s in pairs(saved) do
			list[#list + 1] = { inst, s }
		end
		saved = setmetatable({}, { __mode = "k" })
		task.spawn(function()
			for i, entry in ipairs(list) do
				pcall(function()
					for prop, value in pairs(entry[2]) do
						entry[1][prop] = value
					end
				end)
				if i % 300 == 0 then
					task.wait()
				end
			end
		end)
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11e Stretch: растянутое разрешение (сжатие картинки по вертикали). Значение вводится вручную.
-- Это матрица масштаба оси Y камеры, как в популярных скриптах "stretched res";
-- применяется после камерного скрипта Roblox, поэтому не накапливается.
-- ----------------------------------------------------------------------------
Modules.Stretch = (function()
	local M = {}
	local BIND = "NNProject_Stretch"
	local bound = false
	local lastY

	function M.Enable()
		if bound then
			return
		end
		bound = true
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 3, function()
			local cam = GetCamera()
			if not cam then
				return
			end
			-- у Scriptable-камеры CFrame никто не сбрасывает: сначала снимаем прошлое растяжение
			if lastY and cam.CameraType == Enum.CameraType.Scriptable then
				cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 1 / lastY, 0, 0, 0, 1)
			end
			local y = math.clamp(Settings.StretchRes, 0.5, 1)
			cam.CFrame = cam.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, y, 0, 0, 0, 1)
			lastY = y
		end)
	end

	function M.Disable()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(BIND)
		end
		lastY = nil
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11g CameraBounce: камера плавно отстаёт от игрока и пружинит (от первого лица не работает)
-- ----------------------------------------------------------------------------
Modules.CameraBounce = (function()
	local M = {}
	local BIND = "NNProject_CamBounce"
	local bound = false
	local off, vel, applied = Vector3.zero, Vector3.zero, Vector3.zero

	function M.Enable()
		if bound then
			return
		end
		bound = true
		off, vel, applied = Vector3.zero, Vector3.zero, Vector3.zero
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 4, function(dt)
			local cam, root = GetCamera(), GetRoot()
			if not cam or not root then
				return
			end
			-- у Scriptable-камеры CFrame не сбрасывается: снимаем прошлое смещение
			if cam.CameraType == Enum.CameraType.Scriptable and applied ~= Vector3.zero then
				cam.CFrame = cam.CFrame - applied
			end
			if IsFirstPerson() then
				off, vel, applied = Vector3.zero, Vector3.zero, Vector3.zero
				return
			end
			dt = math.min(dt, 0.1)
			local strength = Settings.CamBounce / 100
			local pv = root.AssemblyLinearVelocity
			-- цель пружины: камера остаётся позади движения; по вертикали проседает при прыжках и падении
			local target = Vector3.new(-pv.X, -pv.Y * 1.2, -pv.Z) * 0.09 * strength
			local limit = 4 * strength
			if target.Magnitude > limit and limit > 0 then
				target = target.Unit * limit
			end
			vel += ((target - off) * 38 - vel * 8) * dt -- чуть недодемпфированная пружина даёт мягкий отскок
			off += vel * dt
			applied = off
			cam.CFrame = cam.CFrame + off
		end)
	end

	function M.Disable()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(BIND)
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11g2 CamPos: смещение камеры по X / Y / Z (нужно, когда аватар визуально выше настоящего).
-- Сдвиг не проходит сквозь стены: луч от камеры до новой позиции укорачивает смещение.
-- ----------------------------------------------------------------------------
Modules.CamPos = (function()
	local M = {}
	local BIND, BIND_END = "NNProject_CamPos", "NNProject_CamPosEnd"
	local MARGIN = 0.5 -- запас до стены, чтобы камера не упиралась вплотную
	local bound = false
	local applied, finalCF, fraction = Vector3.zero, nil, 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	pcall(function()
		params.RespectCanCollide = true -- считаются только стены с включённой коллизией
	end)

	--- Расстояние до ближайшей стены на пути origin -> direction (nil, если путь свободен). Свой персонаж, другие игроки и боты не мешают
	local function wallDistance(origin, direction)
		local ignore = { LocalPlayer.Character }
		for _ = 1, 4 do
			params.FilterDescendantsInstances = ignore
			local hit = Workspace:Raycast(origin, direction, params)
			if not hit then
				return nil
			end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				ignore[#ignore + 1] = model
			else
				return hit.Distance
			end
		end
		return nil
	end

	function M.Enable()
		if bound then
			return
		end
		bound = true
		applied, finalCF, fraction = Vector3.zero, nil, 1
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 2, function(dt)
			local cam = GetCamera()
			if not cam then
				return
			end
			-- Scriptable-камера, которую игра не обновляет: CFrame остаётся нашим, поэтому снимаем прошлое смещение
			if finalCF and cam.CFrame == finalCF and applied ~= Vector3.zero then
				cam.CFrame = cam.CFrame - applied
			end
			local cf = cam.CFrame
			local full = cf.RightVector * (Settings.CamX / 10) + Vector3.new(0, Settings.CamY / 10, 0) + cf.LookVector * (Settings.CamZ / 10)
			local length = full.Magnitude
			local target = 1
			if length > 0.01 then
				local wall = wallDistance(cf.Position, full)
				if wall then
					target = math.clamp((wall - MARGIN) / length, 0, 1) -- запас до стены только когда она есть
				end
			end
			-- к стене камера подъезжает сразу, а от стены возвращается плавно
			if target < fraction then
				fraction = target
			else
				fraction += (target - fraction) * ExpAlpha(10, math.min(dt, 0.1))
			end
			applied = full * fraction
			cam.CFrame = cf + applied
		end)
		-- после всех камерных модулей запоминаем итоговый CFrame (нужно для проверки выше)
		RunService:BindToRenderStep(BIND_END, Enum.RenderPriority.Camera.Value + 8, function()
			local cam = GetCamera()
			if cam then
				finalCF = cam.CFrame
			end
		end)
	end

	function M.Disable()
		if not bound then
			return
		end
		bound = false
		RunService:UnbindFromRenderStep(BIND)
		RunService:UnbindFromRenderStep(BIND_END)
		local cam = GetCamera()
		if cam and finalCF and cam.CFrame == finalCF and applied ~= Vector3.zero then
			cam.CFrame = cam.CFrame - applied
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11h FPerson: показывает ваше тело от первого лица (камеру не переключает)
-- ----------------------------------------------------------------------------
Modules.FPerson = (function()
	local M = {}
	local BIND = "NNProject_FPerson"
	local bound = false

	local function isHeadPart(part, head)
		if part == head then
			return true
		end
		local acc = part:FindFirstAncestorOfClass("Accessory")
		if acc then
			local handle = acc:FindFirstChild("Handle")
			local att = handle and handle:FindFirstChildOfClass("Attachment")
			if att and head:FindFirstChild(att.Name) then
				return true -- аксессуар на голове остаётся скрытым, чтобы не закрывать обзор
			end
		end
		return false
	end

	function M.Enable()
		if bound then
			return
		end
		bound = true
		-- выполняется после камерного скрипта, который сам прячет тело в первом лице
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 5, function()
			local char = LocalPlayer.Character
			local head = char and char:FindFirstChild("Head")
			if not head or not IsFirstPerson() then
				return -- от третьего лица ничего не меняем
			end
			for _, d in ipairs(char:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = isHeadPart(d, head) and 1 or 0
				end
			end
		end)
	end

	function M.Disable()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(BIND)
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11i Crosshair: прицел в стиле Minecraft (виден на ShiftLock и от первого лица)
-- ----------------------------------------------------------------------------
Modules.Crosshair = (function()
	local M = {}
	local maid

	function M.Enable()
		maid = Maid.new()
		local root = Create("Frame", {
			Name = "NN_Crosshair", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false, Parent = ScreenGui,
		}, { Create("UIScale", { Name = "Scale" }) })
		maid:Give(root)
		for _, size in ipairs({ { 16, 2 }, { 2, 16 } }) do
			Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0, 0), Size = UDim2.fromOffset(size[1], size[2]),
				BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.05, BorderSizePixel = 0, Parent = root,
			}, { Create("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.35 }) })
		end
		maid:Give(RunService.RenderStepped:Connect(function()
			root.Visible = IsFirstPerson() or IsLockedCenter()
			root.Scale.Scale = Settings.CrosshairSize / 100
		end))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11j CrosshairBox: плавающий квадрат над поверхностью в центре экрана (ShiftLock или первое лицо).
-- Квадрат парит над точкой попадания луча, ложится по нормали поверхности (повёрнутые блоки и
-- MeshPart - по их коллизии), медленно вращается. Невидимые детали пропускаются.
-- ----------------------------------------------------------------------------
Modules.CrosshairBox = (function()
	local M = {}
	local maid

	local function hitUnderCrosshair()
		local cam = GetCamera()
		if not cam then
			return nil
		end
		local vp = cam.ViewportSize
		local ray = cam:ViewportPointToRay(vp.X / 2, vp.Y / 2)
		local ignore = { FxFolder }
		if LocalPlayer.Character then
			ignore[2] = LocalPlayer.Character
		end
		for _ = 1, 4 do
			rayParams.FilterDescendantsInstances = ignore
			rayParams.RespectCanCollide = false
			local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
			if not result then
				return nil
			end
			if result.Instance.Transparency >= 0.95 then
				ignore[#ignore + 1] = result.Instance
			else
				return result
			end
		end
		return nil
	end

	function M.Enable()
		maid = Maid.new()
		local part = Create("Part", {
			Name = "NN_CrosshairSquare", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, Transparency = 1, Size = Vector3.new(1.2, 0.05, 1.2), Parent = FxFolder,
		})
		maid:Give(part)
		local fills, strokes, guis = {}, {}, {}
		for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Bottom }) do
			local sg = Create("SurfaceGui", {
				Face = face, SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, CanvasSize = Vector2.new(128, 128),
				LightInfluence = 0, Enabled = false, Parent = part,
			})
			pcall(function()
				sg.Brightness = 2.5
			end)
			local stroke = Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 4, Transparency = 1 })
			local fill = Create("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, BackgroundTransparency = 1, Parent = sg }, { stroke })
			guis[#guis + 1], fills[#fills + 1], strokes[#strokes + 1] = sg, fill, stroke
		end

		local current, appear = nil, 0
		maid:Give(RunService.RenderStepped:Connect(function(dt)
			dt = math.min(dt, 0.1)
			local t = os.clock()
			local hit = (IsFirstPerson() or IsLockedCenter()) and hitUnderCrosshair() or nil
			if hit then
				local n = hit.Normal
				local pos = hit.Position + n * (0.35 + math.sin(t * 3) * 0.06) -- парит над поверхностью
				local base = CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0) -- ось Y = нормаль
				local goal = base * CFrame.Angles(0, t * 0.8, 0)
				current = current and current:Lerp(goal, ExpAlpha(16, dt)) or goal
				part.CFrame = current
				appear += (1 - appear) * ExpAlpha(12, dt)
			else
				appear += (0 - appear) * ExpAlpha(12, dt)
			end
			local size = 1.2 * Settings.BoxSize / 100 * (0.6 + 0.4 * appear)
			part.Size = Vector3.new(size, 0.05, size)
			local alpha = Settings.BoxAlpha / 100
			local color = Palette.GetColors()
			for i = 1, #fills do
				guis[i].Enabled = appear > 0.02
				fills[i].BackgroundColor3 = color
				fills[i].BackgroundTransparency = alpha + (1 - alpha) * (1 - appear)
				strokes[i].Transparency = 0.1 + 0.9 * (1 - appear)
			end
		end))
	end

	function M.Disable()
		if maid then
			maid:Clean()
			maid = nil
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.11k ForceThird: камера всегда от 3 лица в любой игре, со своим FOV.
-- Стандартная камера: поднимается минимальный зум. Кастомные системы (первое лицо, Scriptable):
-- если камера оказалась у головы, она отодвигается назад вдоль взгляда (со стеной не пересекается).
-- Совместимо с "Отставанием камеры", косметика при этом показывается как в третьем лице.
-- ----------------------------------------------------------------------------
Modules.ForceThird = (function()
	local M = {}
	local BIND = "NNProject_ForceThird"
	local bound = false
	local saved

	function M.Enable()
		if bound then
			return
		end
		bound = true
		saved = {
			Mode = LocalPlayer.CameraMode,
			Min = LocalPlayer.CameraMinZoomDistance,
			Max = LocalPlayer.CameraMaxZoomDistance,
		}
		RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, function(dt)
			local cam = GetCamera()
			local char = LocalPlayer.Character
			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			if not cam or not head then
				return
			end
			local dist = Settings.ThirdDistance
			pcall(function()
				if LocalPlayer.CameraMode ~= Enum.CameraMode.Classic then
					LocalPlayer.CameraMode = Enum.CameraMode.Classic
				end
				if LocalPlayer.CameraMaxZoomDistance < dist then
					LocalPlayer.CameraMaxZoomDistance = dist
				end
				if LocalPlayer.CameraMinZoomDistance < dist then
					LocalPlayer.CameraMinZoomDistance = dist
				end
			end)
			-- камера слишком близко к голове (первое лицо чужой системы): отодвигаем назад
			local headPos = head.Position
			local camCF = cam.CFrame
			if (camCF.Position - headPos).Magnitude < 3.5 then
				local back = -camCF.LookVector
				local result = Raycast(headPos, back * dist, char, true)
				local d = result and math.max(result.Distance - 0.4, 0.5) or dist
				cam.CFrame = CFrame.new(headPos + back * d) * (camCF - camCF.Position)
			end
			cam.FieldOfView += (Settings.ThirdFov - cam.FieldOfView) * ExpAlpha(10, dt)
		end)
	end

	function M.Disable()
		if bound then
			bound = false
			RunService:UnbindFromRenderStep(BIND)
		end
		if saved then
			local s = saved
			saved = nil
			pcall(function()
				LocalPlayer.CameraMinZoomDistance = s.Min
				LocalPlayer.CameraMaxZoomDistance = s.Max
				LocalPlayer.CameraMode = s.Mode
			end)
		end
	end

	return M
end)()

-- ----------------------------------------------------------------------------
-- 8.12 Интерфейсные "модули" (ватермарка, звуки, уведомления)
-- ----------------------------------------------------------------------------
local function WmToggle(field)
	return {
		Enable = function()
			Watermark.Show[field] = true
			Watermark.Refresh()
		end,
		Disable = function()
			Watermark.Show[field] = false
			Watermark.Refresh()
		end,
	}
end
Modules.WmFps = WmToggle("Fps")
Modules.WmPing = WmToggle("Ping")
Modules.WmNick = WmToggle("Nick")
Modules.WmTariff = WmToggle("Tariff")

Modules.Sounds = {
	Enable = function()
		Sfx.Enabled = true
	end,
	Disable = function()
		Sfx.Enabled = false
	end,
}

Modules.Notifications = {
	Enable = function()
		Notify.Enabled = true
	end,
	Disable = function()
		Notify.Enabled = false
	end,
}

-- Скрытые функции экипировки (выбираются через меню "[Выбор]", отдельной строки нет)
RegisterFeature("Cape", T("Плащ"), T("Экипировка"))


-- ============================================================================
-- 9. МЕНЕДЖЕР ФУНКЦИЙ
-- ============================================================================
local Menu

local function SetFeature(id, enabled, silent)
	local feature = Features[id]
	local module = Modules[id]
	if not feature or not module or feature.Enabled == enabled then
		return false
	end

	local ok, err
	if enabled and Cosmetics.Hidden and Cosmetics.Ids[id] then
		Cosmetics.Suspended[id] = true -- в первом лице не создаём, включится при выходе из него
		ok = true
	elseif not enabled and Cosmetics.Suspended[id] then
		Cosmetics.Suspended[id] = nil
		ok = true
	else
		ok, err = pcall(enabled and module.Enable or module.Disable)
	end
	if not ok then
		warn("[NN-Project] " .. id .. ": " .. tostring(err))
		if enabled then
			pcall(module.Disable)
		end
		local message = tostring(err)
		if #message > 110 then
			message = string.sub(message, 1, 110) .. "..."
		end
		Notify.Error(
			string.format(T("Не удалось %s «%s».\n%s"), enabled and T("включить") or T("выключить"), feature.Name, message),
			enabled and ERR.ENABLE or ERR.DISABLE,
			T("Сбой модуля")
		)
		if feature.UI then
			feature.UI.Set(feature.Enabled, false)
		end
		return false
	end

	feature.Enabled = enabled
	if feature.UI then
		feature.UI.Set(enabled, false)
	end
	if Menu and Menu.RefreshDeps then
		Menu.RefreshDeps()
	end
	if not silent then
		Sfx.Play(enabled and "On" or "Off", 0.6)
		Notify.Info(
			string.format(T("Модуль «%s» успешно %s."), feature.Name, enabled and T("включён") or T("выключен")),
			feature.Section or CONFIG.ProjectName, nil, true
		)
	end
	return true
end

local function RebuildGear()
	if IsEnabled("Cape") then
		pcall(Modules.Cape.Disable)
		pcall(Modules.Cape.Enable)
	end
end

-- ============================================================================
-- 10. ГЛАВНОЕ МЕНЮ: на весь экран, тёмный блюр и пилюли (дизайн по референсам)
-- Раскладка: приветствие -> название -> страницы по 4 колонки пилюль -> "Конфиги" / "О скрипте".
-- Тап по пилюле-переключателю включает функцию; удержание (или правая кнопка мыши) открывает её настройки.
-- ============================================================================
Menu = { IsOpen = false, Locked = true }

local UI = {
	PillW = 190, PillH = 40, PillGap = 8, ColGap = 20, PanelW = 236, HoldTime = 0.35,
	TopH = 124, BottomH = 112,
	Scale = 1, ContentH = 720, Shrink = 0.86, MoveSlop = 14,
	LastToggle = 0, Fade = {}, FadeToken = 0,
	Pills = {}, RowFrames = {}, Pages = {}, Dots = {}, Modals = {},
	LiveDeps = {}, LiveSwitches = {}, Current = 1, Token = 0,
}
UI.DesignW = UI.PillW * 4 + UI.ColGap * 3 + 40
UI.OpenInfo = TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
UI.CloseInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
UI.FadeInfo = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Окно: окно ниже ватермарки и уведомлений (ZIndex 0), поэтому ватермарка остаётся кликабельной
local Window = Create("Frame", {
	Name = "Window", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 0, Parent = ScreenGui,
})
local Dim = Create("Frame", {
	Name = "Dim", BackgroundColor3 = Color3.fromRGB(6, 4, 12), BackgroundTransparency = 1, BorderSizePixel = 0,
	Size = UDim2.fromScale(1, 1), Active = true, Parent = Window,
})
-- Scaler подгоняет масштаб под экран, Content - всё содержимое в "единицах дизайна"
local Scaler = Create("Frame", {
	Name = "Scaler", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = Window,
}, { Create("UIScale", { Name = "UIScale" }) })
local Content = Create("Frame", {
	Name = "Content", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 30),
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = Scaler,
}, { Create("UIScale", { Name = "Pop", Scale = 0.92 }) })
UI.Pop = Content.Pop

-- Блюр игрового мира за меню
local MenuBlur = Create("BlurEffect", { Name = "NN_MenuBlur", Size = 0, Enabled = false, Parent = Lighting })
Root:Give(MenuBlur)

function Menu.UpdateScale(instant)
	local cam = GetCamera()
	local viewport = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local scale = math.clamp(viewport.X / UI.DesignW, 0.4, 1.2) * UI.Shrink * UI_SCALES[Settings.UiScale]
	UI.Scale = scale
	UI.ContentH = viewport.Y / scale
	local size = UDim2.fromScale(1 / scale, 1 / scale)
	if instant then
		Scaler.UIScale.Scale = scale
		Scaler.Size = size
	else
		Tween(Scaler.UIScale, TI.Medium, { Scale = scale })
		Tween(Scaler, TI.Medium, { Size = size })
	end
	local minHeight = math.max(UI.ContentH - UI.TopH - UI.BottomH, 120)
	for _, row in ipairs(UI.RowFrames) do
		row.Size = UDim2.new(1, 0, 0, minHeight)
	end
end

do
	local connection
	local function hook()
		if connection then
			connection:Disconnect()
		end
		local cam = GetCamera()
		if cam then
			connection = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				Menu.UpdateScale(false)
			end)
		end
	end
	hook()
	Root:Give(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hook()
		Menu.UpdateScale(true)
	end))
	Root:Give(function()
		if connection then
			connection:Disconnect()
		end
	end)
	Menu.UpdateScale(true)
end

-- ---------------------------------------------------------------- шапка: приветствие, название, билд
do
	local displayName = CONFIG.UseDisplayName and LocalPlayer.DisplayName or LocalPlayer.Name
	local header = Create("CanvasGroup", {
		Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, UI.TopH), GroupTransparency = 1, Parent = Content,
	})
	UI.Fade[#UI.Fade + 1] = { Group = header, Delay = 0 }
	Create("TextLabel", {
		Name = "Greeting", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 28), Size = UDim2.new(1, -40, 0, 26),
		BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 21, TextColor3 = Color3.fromRGB(236, 232, 244),
		Text = T("С возвращением, ") .. displayName .. ".", Parent = header,
	})
	local block = Create("Frame", {
		Name = "TitleBlock", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1, Parent = header,
	}, { Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 0) }) })
	Make("TextLabel", {
		Name = "Title", LayoutOrder = 1, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium, TextSize = 38, Text = CONFIG.MenuTitle, Skin = { TextColor3 = "AccentSoft" }, Parent = block,
	})
	Create("TextLabel", {
		Name = "Build", LayoutOrder = 2, Size = UDim2.fromOffset(0, 0), AutomaticSize = Enum.AutomaticSize.XY, BackgroundTransparency = 1,
		Font = Enum.Font.RobotoMono, TextSize = 13, TextColor3 = Color3.fromRGB(226, 220, 236),
		Text = string.format("build %s%s | %s", CONFIG.Version, CONFIG.Patch ~= "" and ("." .. CONFIG.Patch) or "", CONFIG.Generation), Parent = block,
	})
end

-- ---------------------------------------------------------------- всплывающее окно (пикер цвета)
local ActivePopup

local function ClosePopup()
	if ActivePopup then
		local popup = ActivePopup
		ActivePopup = nil
		popup.Close()
	end
end

-- ---------------------------------------------------------------- пикер цвета (квадрат + кольцо оттенков, HEX и RGB)
local function OpenColorPicker(initial, onChange)
	ClosePopup()
	local pmaid = Maid.new()
	local catcher = Create("TextButton", {
		Name = "PickerCatcher", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, Text = "",
		AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = 40, Parent = Content,
	})
	local panel = Make("CanvasGroup", {
		Name = "ColorPicker", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.fromOffset(300, 200), GroupTransparency = 1, BorderSizePixel = 0, ZIndex = 41, Active = true,
		Skin = { BackgroundColor3 = "Pill" }, Parent = Content,
	}, { Corner(UDim.new(0, 16)), Make("UIStroke", { Thickness = 1, Transparency = 0.2, Skin = { Color = "Stroke" } }) })
	Tween(panel, TI.Fast, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) })

	local CENTER = Vector2.new(82, 82) -- центр кольца внутри области 164x164
	local R_OUT, R_IN, SQ = 80, 60, 38
	local area = Create("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(12, 18), Size = UDim2.fromOffset(164, 164), Parent = panel })

	-- кольцо оттенков из 72 повёрнутых сегментов
	local SEGMENTS = 72
	for i = 0, SEGMENTS - 1 do
		local angle = (i + 0.5) / SEGMENTS * math.pi * 2
		local rMid = (R_OUT + R_IN) / 2
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(CENTER.X + math.cos(angle) * rMid, CENTER.Y + math.sin(angle) * rMid),
			Size = UDim2.fromOffset(R_OUT - R_IN + 1, 7), Rotation = math.deg(angle), BorderSizePixel = 0,
			BackgroundColor3 = Color3.fromHSV(i / SEGMENTS, 1, 1), Parent = area,
		})
	end

	-- квадрат насыщенности/яркости: цвет оттенка + белый градиент слева + чёрный градиент снизу
	local square = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(CENTER.X, CENTER.Y), Size = UDim2.fromOffset(SQ * 2, SQ * 2),
		BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 0, 0), Parent = area,
	}, { Corner(UDim.new(0, 4)) })
	Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = square }, {
		Corner(UDim.new(0, 4)),
		Create("UIGradient", { Transparency = NS({ NSK(0, 0), NSK(1, 1) }) }),
	})
	Create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = square }, {
		Corner(UDim.new(0, 4)),
		Create("UIGradient", { Rotation = 90, Transparency = NS({ NSK(0, 1), NSK(1, 0) }) }),
	})
	local sqDot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 3, Parent = area,
	}, { Corner(UDim.new(1, 0)), Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })
	local ringDot = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, ZIndex = 3, Parent = area,
	}, { Corner(UDim.new(1, 0)), Create("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }) })

	-- правая колонка: превью, HEX, RGB, кнопка
	local preview = Create("Frame", {
		Position = UDim2.fromOffset(192, 18), Size = UDim2.fromOffset(94, 32), BorderSizePixel = 0, Parent = panel,
	}, { Corner(UDim.new(0, 8)) })
	local function box(x, y, w, placeholder)
		return Make("TextBox", {
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, 26), BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
			TextSize = 12, TextColor3 = THEME.Text, PlaceholderText = placeholder, ClearTextOnFocus = false, Text = "",
			Skin = { BackgroundColor3 = "Panel" }, Parent = panel,
		}, { Corner(UDim.new(0, 8)) })
	end
	local hexBox = box(192, 58, 94, "#RRGGBB")
	local rBox, gBox, bBox = box(192, 92, 29, "R"), box(224, 92, 29, "G"), box(256, 92, 29, "B")
	local done = Make("TextButton", {
		Position = UDim2.fromOffset(192, 146), Size = UDim2.fromOffset(94, 30), BorderSizePixel = 0, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = THEME.Text, Text = T("Готово"), Skin = { BackgroundColor3 = "SwitchOn" }, Parent = panel,
	}, { Corner(UDim.new(1, 0)) })

	local h, s, v = initial:ToHSV()
	local function update(fire)
		local color = Color3.fromHSV(h, s, v)
		square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		preview.BackgroundColor3 = color
		local a = h * math.pi * 2
		local rMid = (R_OUT + R_IN) / 2
		ringDot.Position = UDim2.fromOffset(CENTER.X + math.cos(a) * rMid, CENTER.Y + math.sin(a) * rMid)
		sqDot.Position = UDim2.fromOffset(CENTER.X - SQ + s * SQ * 2, CENTER.Y - SQ + (1 - v) * SQ * 2)
		hexBox.Text = ColorToHex(color)
		rBox.Text, gBox.Text, bBox.Text = tostring(math.floor(color.R * 255 + 0.5)), tostring(math.floor(color.G * 255 + 0.5)), tostring(math.floor(color.B * 255 + 0.5))
		if fire then
			onChange(color)
		end
	end
	update(false)

	local function setColor(color)
		h, s, v = color:ToHSV()
		update(true)
	end
	hexBox.FocusLost:Connect(function()
		local c = HexToColor(hexBox.Text)
		if c then
			setColor(c)
		else
			update(false)
		end
	end)
	for _, b in ipairs({ rBox, gBox, bBox }) do
		b.FocusLost:Connect(function()
			local r, g, bl = tonumber(rBox.Text), tonumber(gBox.Text), tonumber(bBox.Text)
			if r and g and bl then
				setColor(Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(bl, 0, 255)))
			else
				update(false)
			end
		end)
	end

	-- перетаскивание по кольцу и квадрату (координаты делятся на масштаб интерфейса)
	local hit = Create("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = area })
	local mode
	local function handle(pos)
		local k = area.AbsoluteSize.X / 164
		local d = (pos - area.AbsolutePosition) / math.max(k, 0.01) - CENTER
		if mode == "ring" then
			h = (math.atan2(d.Y, d.X) / (math.pi * 2)) % 1
		elseif mode == "sq" then
			s = math.clamp((d.X + SQ) / (SQ * 2), 0, 1)
			v = 1 - math.clamp((d.Y + SQ) / (SQ * 2), 0, 1)
		end
		update(true)
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local k = area.AbsoluteSize.X / 164
		local d = (Vector2.new(input.Position.X, input.Position.Y) - area.AbsolutePosition) / math.max(k, 0.01) - CENTER
		local r = d.Magnitude
		if r >= R_IN - 6 and r <= R_OUT + 8 then
			mode = "ring"
		elseif math.abs(d.X) <= SQ + 4 and math.abs(d.Y) <= SQ + 4 then
			mode = "sq"
		else
			return
		end
		handle(Vector2.new(input.Position.X, input.Position.Y))
		local conn
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				mode = nil
				conn:Disconnect()
			end
		end)
	end)
	pmaid:Give(UserInputService.InputChanged:Connect(function(input)
		if mode and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			handle(Vector2.new(input.Position.X, input.Position.Y))
		end
	end))

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		pmaid:Clean()
		catcher:Destroy()
		local tw = Tween(panel, TI.Fast, { GroupTransparency = 1 })
		tw.Completed:Connect(function()
			panel:Destroy()
		end)
	end
	ActivePopup = { Close = close }
	catcher.Activated:Connect(function()
		ClosePopup()
	end)
	done.Activated:Connect(function()
		ClosePopup()
	end)
end

-- ---------------------------------------------------------------- тесты
local test = {}
function test.Notification()
	Notify.Info(T("Тестовое уведомление. Визуальные эффекты работают корректно."), T("Проверка"))
end
function test.Error()
	Notify.Error(T("Это тестовая ошибка: так выглядят сообщения о сбоях модулей."), ERR.TEST, T("Проверка"))
end
function test.Shake()
	Modules.ScreenShake.Shake(0.9, 0.7, { Mode = "noise", Frequency = 28, Rotation = 1.3 })
end
function test.Lightning()
	DeathFx.TestLightning()
end
function test.Decay()
	DeathFx.TestDecay()
end
function test.DeathSound()
	PlayAsset(DEATH_SOUNDS[Settings.DeathSound].Id, Settings.DeathVolume / 100, 8)
end
function test.HitSound()
	PlayAsset(HIT_SOUNDS[Settings.HitSound].Id, Settings.HitVolume / 100, 4)
end

local function names(list)
	local out = {}
	for i, item in ipairs(list) do
		out[i] = type(item) == "table" and item.Name or item
	end
	return out
end

local function Toggle(id, name, desc, requires)
	return { Type = "toggle", Id = id, Name = name, Desc = desc, Requires = requires }
end

local Unload

-- ---------------------------------------------------------------- конфиги: хранилище, сбор и применение
local Config = {}
do
	local DIR = "NN-Project/configs"
	local memory = _G.NNProject_ConfigMemory or {}
	_G.NNProject_ConfigMemory = memory

	local function fsOk()
		return type(writefile) == "function" and type(readfile) == "function" and type(isfolder) == "function"
			and type(makefolder) == "function" and type(listfiles) == "function"
	end
	Config.HasFiles = fsOk()

	local function ensureDir()
		if not isfolder("NN-Project") then
			makefolder("NN-Project")
		end
		if not isfolder(DIR) then
			makefolder(DIR)
		end
	end

	function Config.Sanitize(name)
		name = tostring(name or ""):gsub("[^%w_%-]+", "_"):gsub("^_+", ""):gsub("_+$", "")
		return string.sub(name, 1, 24)
	end

	function Config.List()
		local out = {}
		if Config.HasFiles then
			pcall(function()
				ensureDir()
				for _, path in ipairs(listfiles(DIR)) do
					local name = tostring(path):match("([^/\\]+)%.json$")
					if name then
						out[#out + 1] = name
					end
				end
			end)
		else
			for name in pairs(memory) do
				out[#out + 1] = name
			end
		end
		table.sort(out)
		return out
	end

	function Config.Exists(name)
		for _, n in ipairs(Config.List()) do
			if n == name then
				return true
			end
		end
		return false
	end

	function Config.Write(name, json)
		if Config.HasFiles then
			ensureDir()
			writefile(DIR .. "/" .. name .. ".json", json)
		else
			memory[name] = json
		end
	end

	function Config.Read(name)
		if Config.HasFiles then
			return readfile(DIR .. "/" .. name .. ".json")
		end
		return memory[name]
	end

	function Config.Delete(name)
		if Config.HasFiles then
			if type(delfile) == "function" then
				delfile(DIR .. "/" .. name .. ".json")
			else
				writefile(DIR .. "/" .. name .. ".json", "{}")
			end
		else
			memory[name] = nil
		end
	end

	--- Текущее состояние: настройки, включённые функции, палитра
	function Config.Collect()
		local data = { Version = CONFIG.Version, Settings = {}, Features = {}, Palette = Palette.Index }
		for key, value in pairs(Settings) do
			if typeof(value) == "Color3" then
				data.Settings[key] = ColorToHex(value)
			elseif type(value) == "number" or type(value) == "boolean" then
				data.Settings[key] = value
			end
		end
		for id, feature in pairs(Features) do
			if feature.Enabled and id ~= "Potato" then -- режим картошки в конфиги не попадает
				data.Features[id] = true
			end
		end
		return HttpService:JSONEncode(data)
	end

	local LIMITS = {
		AuraLevel = AURA_LEVELS, UiScale = UI_SCALES, NotifyDurationIndex = NOTIFY_DURATIONS, UiSkin = UI_SKINS,
		GearColor = GEAR_COLORS, CapeMaterial = CAPE_MATERIALS, SnowLevel = SNOW_LEVELS, Time = TIME_PRESETS,
		Fog = FOG_MODES, Grade = GRADES, TargetStyle = TARGET_STYLES, TargetStyle2 = TARGET_STYLES, DeathTargets = DEATH_TARGETS,
		DeathSound = DEATH_SOUNDS, HitSound = HIT_SOUNDS, HitMode = HIT_MODES,
		WmH = { 1, 2, 3 }, WmV = { 1, 2 }, NotifyH = { 1, 2, 3 }, NotifyV = { 1, 2 },
	}

	function Config.Apply(json)
		local ok, data = pcall(function()
			return HttpService:JSONDecode(json)
		end)
		if not ok or type(data) ~= "table" then
			error(T("файл конфига повреждён"))
		end
		for key, value in pairs(data.Settings or {}) do
			local current = Settings[key]
			if typeof(current) == "Color3" and type(value) == "string" then
				Settings[key] = HexToColor(value) or current
			elseif current ~= nil and type(current) == type(value) then
				Settings[key] = value
			end
		end
		for key, list in pairs(LIMITS) do
			Settings[key] = math.clamp(math.floor(Settings[key]), 1, #list)
		end
		Settings.Fov = math.clamp(Settings.Fov, 40, 120)
		Settings.FogStrength = math.clamp(Settings.FogStrength, 1, 100)
		Settings.WmScale = math.clamp(Settings.WmScale, 60, 160)
		Settings.NotifyScale = math.clamp(Settings.NotifyScale, 60, 150)
		Settings.TargetFov = math.clamp(Settings.TargetFov, 3, 100)
		Settings.TargetRange = math.clamp(Settings.TargetRange, 10, 300)
		Settings.StretchRes = math.clamp(Settings.StretchRes, 0.5, 1)
		Settings.BlurPower = math.clamp(Settings.BlurPower, 0, 100)
		Settings.GlowPower = math.clamp(Settings.GlowPower, 0, 100)
		Settings.FireflySize = math.clamp(Settings.FireflySize, 10, 150)
		Settings.TrailLength = math.clamp(Settings.TrailLength, 1, 80)
		Settings.TrailLife = math.clamp(Settings.TrailLife, 1, 30)
		Settings.TrailWidth = math.clamp(Settings.TrailWidth, 2, 60)
		Settings.OrbitCount = math.clamp(math.floor(Settings.OrbitCount), 2, 16)
		Settings.CamBounce = math.clamp(Settings.CamBounce, 0, 100)
		Settings.BoxSize = math.clamp(Settings.BoxSize, 10, 200)
		Settings.BoxAlpha = math.clamp(Settings.BoxAlpha, 0, 95)
		Settings.CrosshairSize = math.clamp(Settings.CrosshairSize, 50, 200)
		Settings.ThirdDistance = math.clamp(Settings.ThirdDistance, 3, 40)
		Settings.ThirdFov = math.clamp(Settings.ThirdFov, 40, 120)
		Settings.WaveInterval = math.clamp(Settings.WaveInterval, 1, 15)
		Settings.WaveRange = math.clamp(Settings.WaveRange, 3, 25)
		Settings.DeathVolume = math.clamp(Settings.DeathVolume, 0, 100)
		Settings.HitVolume = math.clamp(Settings.HitVolume, 0, 100)
		Settings.HitRange = math.clamp(Settings.HitRange, 10, 300)
		Settings.CamX = math.clamp(Settings.CamX, -100, 100)
		Settings.CamY = math.clamp(Settings.CamY, -50, 150)
		Settings.CamZ = math.clamp(Settings.CamZ, -100, 100)
		Settings.HatSize = math.clamp(Settings.HatSize, 50, 200)
		Settings.HatHeight = math.clamp(Settings.HatHeight, -10, 40)
		Settings.TargetInfoX = math.clamp(Settings.TargetInfoX, 0, 200)
		Settings.TargetInfoY = math.clamp(Settings.TargetInfoY, 0, 200)
		Settings.TargetInfoScale = math.clamp(Settings.TargetInfoScale, 50, 160)
		if IsMobile then
			Settings.UiScale = 1 -- на телефоне доступен только масштаб 80%
		end
		Palette.Index = math.clamp(math.floor(tonumber(data.Palette) or Palette.Index), 1, #Palette.Schemes)

		CONFIG.NotifyDuration = NOTIFY_DURATIONS[Settings.NotifyDurationIndex]
		Palette.Changed:Fire()
		Skin.Apply(Settings.UiSkin, false)
		Menu.UpdateScale(false)
		Watermark.Relayout(true)
		Notify.Relayout()
		Env.SetFog(Settings.Fog)
		Env.SetGrade(Settings.Grade)
		TimeCtl.Set(Settings.Time)
		for id in pairs(Features) do
			if id ~= "Potato" then
				SetFeature(id, (data.Features or {})[id] == true, true)
			end
		end
		Menu.RefreshRows()
	end
end

-- ---------------------------------------------------------------- калибровка зоны таргета (FOV)
local function OpenFovCalibration()
	if Menu.Calibrating then
		return
	end
	Menu.Calibrating = true
	local wasWatermark = Watermark.Visible
	local prevNotify = Notify.Enabled
	Notify.Enabled = false
	NotifyHolder.Visible = false -- на время настройки скрываем ватермарку и все уведомления
	if wasWatermark then
		Watermark.SetVisible(false)
	end
	Menu.Close()

	local gui = Create("ScreenGui", {
		Name = "NNProject_TargetFov", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2500,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = PlayerGui,
	})
	Root:Give(gui)
	local dim = Create("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		Active = true, Parent = gui,
	})
	Tween(dim, TI.Medium, { BackgroundTransparency = 0.25 })

	-- кружок-превью: после сохранения нигде не отображается, это "невидимая" настройка
	local circle = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1, Parent = dim,
	}, { Corner(UDim.new(1, 0)), Create("UIStroke", { Color = THEME.Accent, Thickness = 3 }) })

	-- верхняя кнопка "Готово"
	local topPill = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(240, 52),
		BackgroundColor3 = THEME.Background, BorderSizePixel = 0, Parent = dim,
	}, { Corner(UDim.new(1, 0)) })
	local doneButton = Create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(200, 38),
		BackgroundColor3 = THEME.SwitchOn, BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamMedium,
		TextSize = 15, TextColor3 = THEME.Text, Text = T("Готово"), Parent = topPill,
	}, { Corner(UDim.new(1, 0)) })

	-- нижняя часть: подсказка и слайдер процента
	local bottom = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.fromOffset(460, 156),
		BackgroundTransparency = 1, Parent = dim,
	})
	local hint = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 72), BackgroundColor3 = THEME.Background, BorderSizePixel = 0, Parent = bottom,
	}, { Corner(UDim.new(0, 28)) })
	Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -40, 1, 0), Font = Enum.Font.GothamMedium,
		TextSize = 14, TextColor3 = THEME.Text, TextWrapped = true,
		Text = T("Выберите нужный вам FOV, в который должны попадать конечности игрока"), Parent = hint,
	})
	local sliderPill = Create("Frame", {
		Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 76), BackgroundColor3 = THEME.Background,
		BorderSizePixel = 0, Parent = bottom,
	}, { Corner(UDim.new(0, 30)) })
	local percentLabel = Create("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(26, 10), Size = UDim2.fromOffset(200, 20), Font = Enum.Font.GothamMedium,
		TextSize = 15, TextColor3 = THEME.AccentSoft, TextXAlignment = Enum.TextXAlignment.Left, Text = "", Parent = sliderPill,
	})
	local track = Create("Frame", {
		Position = UDim2.fromOffset(26, 46), Size = UDim2.new(1, -52, 0, 4), BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0, Parent = sliderPill,
	}, { Corner(UDim.new(1, 0)) })
	local knob = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = THEME.AccentSoft, BorderSizePixel = 0, ZIndex = 2, Parent = track,
	}, { Corner(UDim.new(1, 0)) })
	local hit = Create("TextButton", {
		BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -32, 0, 36), Parent = sliderPill,
	})

	local MIN, MAX = 3, 100
	local function setPercent(p)
		p = math.clamp(math.floor(p + 0.5), MIN, MAX)
		Settings.TargetFov = p
		local cam = GetCamera()
		local diameter = (cam and cam.ViewportSize.Y or 720) * p / 100
		circle.Size = UDim2.fromOffset(diameter, diameter)
		percentLabel.Text = p .. "%"
		knob.Position = UDim2.fromScale((p - MIN) / (MAX - MIN), 0.5)
	end
	setPercent(Settings.TargetFov)

	local dragging = false
	local function fromX(x)
		setPercent(MIN + math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1) * (MAX - MIN))
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromX(input.Position.X)
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
				end
			end)
		end
	end)
	local moveConn = UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end)

	doneButton.Activated:Connect(function()
		moveConn:Disconnect()
		local out = Tween(dim, TI.Medium, { BackgroundTransparency = 1 })
		for _, child in ipairs(dim:GetChildren()) do
			if child:IsA("GuiObject") and child ~= circle then
				Tween(child, TI.Fast, { BackgroundTransparency = 1 })
			end
		end
		circle:Destroy() -- кружок исчезает: настройка сохранена и больше не отображается
		out.Completed:Wait()
		gui:Destroy()
		Notify.Enabled = prevNotify
		NotifyHolder.Visible = true
		if wasWatermark then
			Watermark.SetVisible(true)
		end
		Menu.Calibrating = false
		Menu.Open()
	end)
end

-- ---------------------------------------------------------------- структура меню
local SECTIONS = {
	{
		Title = T("ВИЗУАЛЫ"),
		Columns = {
			{ Title = T("Персонаж"), Rows = {
				{ Type = "toggle", Id = "TrailTorso", Name = T("Трейл: от торса"), Desc = T("Плоская лента от торса"), Exclusive = { "TrailFeet" } },
				{ Type = "toggle", Id = "TrailFeet", Name = T("Трейл: от ног"), Desc = T("Лента от ног, видна со всех сторон"), Exclusive = { "TrailTorso" } },
				{ Type = "slider", Name = T("Длина"), Desc = T("Макс. длина, студы"), Min = 1, Max = 80, Requires = { "TrailTorso", "TrailFeet" },
					Get = function() return Settings.TrailLength end, Format = function(v) return v .. T(" ст.") end,
					OnChange = function(v)
						Settings.TrailLength = v
						Modules.TrailTorso.Refresh()
						Modules.TrailFeet.Refresh()
					end },
				{ Type = "slider", Name = T("Время"), Desc = T("Секунды жизни"), Min = 1, Max = 30, Requires = { "TrailTorso", "TrailFeet" },
					Get = function() return Settings.TrailLife end, Format = function(v) return string.format(T("%.1f с"), v * 0.1) end,
					OnChange = function(v)
						Settings.TrailLife = v
						Modules.TrailTorso.Refresh()
						Modules.TrailFeet.Refresh()
					end },
				{ Type = "slider", Name = T("Ширина"), Desc = T("Студы"), Min = 2, Max = 60, Requires = { "TrailTorso", "TrailFeet" },
					Get = function() return Settings.TrailWidth end, Format = function(v) return string.format("%.1f", v * 0.1) end,
					OnChange = function(v)
						Settings.TrailWidth = v
						Modules.TrailTorso.Refresh()
						Modules.TrailFeet.Refresh()
					end },
				Toggle("Aura", T("Аура частиц"), T("Частицы и свечение вокруг тела")),
				Toggle("OrbitAura", T("Орбитальная аура"), T("Шары с лентами, покачиваются при ходьбе")),
				{ Type = "slider", Name = T("Орбиты"), Desc = T("Количество шаров"), Min = 2, Max = 16, Requires = { "OrbitAura" },
					Get = function() return Settings.OrbitCount end,
					OnChange = function(v)
						Settings.OrbitCount = v
						if IsEnabled("OrbitAura") and not Cosmetics.Hidden then
							pcall(Modules.OrbitAura.Disable)
							pcall(Modules.OrbitAura.Enable)
						end
					end },
				Toggle("GlowHat", T("Светящаяся шляпа"), T("Конус из лучей над головой")),
				{ Type = "slider", Name = T("Размер шляпы"), Desc = T("Шляпа"), Min = 50, Max = 200, Requires = { "GlowHat" },
					Get = function() return Settings.HatSize end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.HatSize = v
						Modules.GlowHat.Rebuild()
					end },
				{ Type = "slider", Name = T("Высота шляпы"), Desc = T("Шляпа"), Min = -10, Max = 40, Requires = { "GlowHat" },
					Get = function() return Settings.HatHeight end, Format = function(v) return string.format("%+.1f", v / 10) end,
					OnChange = function(v)
						Settings.HatHeight = v
						Modules.GlowHat.Rebuild()
					end },
			} },
			{ Title = T("Плащ"), Rows = {
				Toggle("Cape", T("Плащ"), T("Один блок, висит на шарнире")),
				{ Type = "cycle", Name = T("Цвет"), Desc = T("Цвет плаща"), Options = names(GEAR_COLORS), Requires = { "Cape" },
					Get = function() return Settings.GearColor end,
					OnChange = function(i) Settings.GearColor = i RebuildGear() end },
				{ Type = "cycle", Name = T("Материал"), Desc = "Neon / Forcefield / Glass", Options = names(CAPE_MATERIALS), Requires = { "Cape" },
					Get = function() return Settings.CapeMaterial end,
					OnChange = function(i) Settings.CapeMaterial = i RebuildGear() end },
			} },
		},
	},
	{
		Title = T("ЭФФЕКТЫ"),
		Columns = {
			{ Title = T("Бой"), Rows = {
				Toggle("ScreenShake", T("Тряска камеры"), T("Реакция на получаемый урон")),
				Toggle("DeathFX", T("Смерть: молния"), T("Разрыв на частицы и молния")),
				Toggle("DeathDecay", T("Смерть: распад"), T("Рассыпается на частицы, без молнии")),
				Toggle("DeathSound", T("Звук смерти"), T("Звук при смерти игрока")),
				{ Type = "cycle", Name = T("Цели смерти"), Desc = T("Для кого играет"), Options = DEATH_TARGETS, Requires = { "DeathFX", "DeathDecay", "DeathSound" },
					Get = function() return Settings.DeathTargets end, OnChange = function(i) Settings.DeathTargets = i end },
				{ Type = "cycle", Name = T("Звук"), Desc = T("Какой звук играет"), Options = names(DEATH_SOUNDS), Requires = { "DeathSound" },
					Get = function() return Settings.DeathSound end, OnChange = function(i) Settings.DeathSound = i end },
				{ Type = "slider", Name = T("Громкость"), Desc = T("Звук смерти (громкость)"), Min = 0, Max = 100, Requires = { "DeathSound" },
					Get = function() return Settings.DeathVolume end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.DeathVolume = v end },
				{ Type = "button", Name = T("Проверить звук"), Desc = T("Звук смерти (громкость)"), Requires = { "DeathSound" }, OnClick = test.DeathSound },
				Toggle("HitSound", T("Звук попадания"), T("Звук, когда у цели отнимается HP или по логам")),
				{ Type = "cycle", Name = T("Звук"), Desc = T("Какой звук играет"), Options = names(HIT_SOUNDS), Requires = { "HitSound" },
					Get = function() return Settings.HitSound end, OnChange = function(i) Settings.HitSound = i end },
				{ Type = "cycle", Name = T("Что считать ударом"), Desc = T("Звук, когда у цели отнимается HP или по логам"), Options = HIT_MODES, Requires = { "HitSound" },
					Get = function() return Settings.HitMode end, OnChange = function(i) Settings.HitMode = i end },
				{ Type = "slider", Name = T("Радиус попадания"), Desc = T("Макс. дистанция до цели"), Min = 10, Max = 300, Requires = { "HitSound" },
					Get = function() return Settings.HitRange end, Format = function(v) return v .. T(" ст.") end,
					OnChange = function(v) Settings.HitRange = v end },
				{ Type = "slider", Name = T("Громкость"), Desc = T("Звук попадания"), Min = 0, Max = 100, Requires = { "HitSound" },
					Get = function() return Settings.HitVolume end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.HitVolume = v end },
				{ Type = "button", Name = T("Проверить звук"), Desc = T("Звук попадания"), Requires = { "HitSound" }, OnClick = test.HitSound },
			} },
			{ Title = T("Цель"), Rows = {
				Toggle("TargetAura", T("Таргет-эффект"), T("Аура на цели в прицеле")),
				Toggle("TargetInfo", T("Инфо о цели"), T("HP, ник и Display Name сверху")),
				Toggle("TargetRigs", T("Боты и Rig"), T("Таргет и на ботах с Humanoid"), { "TargetAura", "TargetInfo" }),
				{ Type = "button", Name = T("Зона таргета"), Desc = T("Настроить FOV прицела"), Requires = { "TargetAura", "TargetInfo" },
					OnClick = OpenFovCalibration },
				{ Type = "slider", Name = T("Дистанция"), Desc = T("Макс. дальность"), Min = 10, Max = 300, Requires = { "TargetAura", "TargetInfo" },
					Get = function() return Settings.TargetRange end, Format = function(v) return v .. T(" ст.") end,
					OnChange = function(v) Settings.TargetRange = v end },
				{ Type = "cycle", Name = T("Стиль таргета"), Desc = T("Вид ауры"), Options = TARGET_STYLES, Requires = { "TargetAura" },
					Get = function() return Settings.TargetStyle end,
					OnChange = function(i)
						Settings.TargetStyle = i
						Target.Refresh()
					end },
				{ Type = "slider", Name = T("Позиция X"), Desc = T("Карточка цели"), Min = 0, Max = 200, Requires = { "TargetInfo" },
					Get = function() return Settings.TargetInfoX end, Format = function(v) return string.format("%.1f%%", v / 2) end,
					OnChange = function(v)
						Settings.TargetInfoX = v
						Target.LayoutInfo()
						Target.PreviewInfo()
					end },
				{ Type = "slider", Name = T("Позиция Y"), Desc = T("Карточка цели"), Min = 0, Max = 200, Requires = { "TargetInfo" },
					Get = function() return Settings.TargetInfoY end, Format = function(v) return string.format("%.1f%%", v / 2) end,
					OnChange = function(v)
						Settings.TargetInfoY = v
						Target.LayoutInfo()
						Target.PreviewInfo()
					end },
				{ Type = "slider", Name = T("Размер"), Desc = T("Карточка цели"), Min = 50, Max = 160, Requires = { "TargetInfo" },
					Get = function() return Settings.TargetInfoScale end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.TargetInfoScale = v
						Target.LayoutInfo()
						Target.PreviewInfo()
					end },
				{ Type = "button", Name = T("Показать превью"), Desc = T("Карточка цели"), Requires = { "TargetInfo" }, OnClick = function() Target.PreviewInfo() end },
				Toggle("TargetMerge", T("Объединение двух стилей"), T("Показывать сразу два стиля ауры"), { "TargetAura" }),
				{ Type = "cycle", Name = T("Второй стиль"), Desc = T("Вид второй ауры"), Options = TARGET_STYLES, Requires = { "TargetAura" },
					When = function() return IsEnabled("TargetMerge") end,
					Get = function() return Settings.TargetStyle2 end,
					OnChange = function(i)
						Settings.TargetStyle2 = i
						Target.Refresh()
					end },
			} },
		},
	},
	{
		Title = T("МИР"),
		Columns = {
			{ Title = T("Погода и свет"), Rows = {
				Toggle("Snow", T("Снег"), T("Крупный снег по всей карте")),
				{ Type = "cycle", Name = T("Сила снега"), Desc = T("Плотность"), Options = names(SNOW_LEVELS), Requires = { "Snow" },
					Get = function() return Settings.SnowLevel end,
					OnChange = function(i)
						Settings.SnowLevel = i
						if IsEnabled("Snow") then
							pcall(Modules.Snow.Disable)
							pcall(Modules.Snow.Enable)
						end
					end },
				Toggle("Rain", T("Дождь"), T("Тихий быстрый дождь со звуком")),
				Toggle("Fireflies", T("Светлячки"), T("Мягкие огоньки вокруг игрока")),
				{ Type = "color", Name = T("Цвет"), Desc = T("Светлячки"), Requires = { "Fireflies" },
					Get = function() return Settings.FireflyColor end,
					OnChange = function(c)
						Settings.FireflyColor = c
						Modules.Fireflies.Refresh()
					end },
				{ Type = "slider", Name = T("Размер"), Desc = T("Светлячки"), Min = 10, Max = 150, Requires = { "Fireflies" },
					Get = function() return Settings.FireflySize end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.FireflySize = v
						Modules.Fireflies.Refresh()
					end },
				{ Type = "cycle", Name = T("Время суток"), Desc = T("Фиксирует время"), Options = names(TIME_PRESETS),
					Get = function() return Settings.Time end, OnChange = function(i) TimeCtl.Set(i) end },
				{ Type = "cycle", Name = T("Туман"), Desc = T("Пресеты и кастом"), Options = names(FOG_MODES),
					Get = function() return Settings.Fog end, OnChange = function(i) Env.SetFog(i) end },
				{ Type = "color", Name = T("Цвет тумана"), Desc = T("Для режима «Кастом.»"),
					When = function() return FOG_MODES[Settings.Fog].Custom == true end,
					Get = function() return Settings.FogColor end,
					OnChange = function(c)
						Settings.FogColor = c
						Env.LiveFog()
					end },
				{ Type = "slider", Name = T("Сила тумана"), Desc = T("Для режима «Кастом.»"), Min = 1, Max = 100,
					When = function() return FOG_MODES[Settings.Fog].Custom == true end,
					Get = function() return Settings.FogStrength end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.FogStrength = v
						Env.LiveFog()
					end },
			} },
			{ Title = T("Поверхность"), Rows = {
				Toggle("FootTrails", T("Следы шагов"), T("Светящиеся отпечатки на полу")),
				Toggle("WalkWaves", T("Волны при ходьбе"), T("Круги от шагов, прыжка и падения")),
				{ Type = "slider", Name = T("Интервал волн"), Desc = T("Секунды между"), Min = 1, Max = 15, Requires = { "WalkWaves" },
					Get = function() return Settings.WaveInterval end, Format = function(v) return string.format(T("%.1f с"), v * 0.1) end,
					OnChange = function(v) Settings.WaveInterval = v end },
				{ Type = "slider", Name = T("Дальность волн"), Desc = T("Радиус, студы"), Min = 3, Max = 25, Requires = { "WalkWaves" },
					Get = function() return Settings.WaveRange end, Format = function(v) return v .. T(" ст.") end,
					OnChange = function(v) Settings.WaveRange = v end },
				Toggle("Potato", T("Режим картошки"), T("Убирает текстуры, только у вас")),
			} },
		},
	},
	{
		Title = T("ЭКРАН"),
		Columns = {
			{ Title = T("Ватермарка"), Rows = {
				Toggle("WmFps", "FPS", T("Показывать FPS")),
				Toggle("WmPing", T("Пинг"), T("Показывать пинг")),
				Toggle("WmNick", T("Ник"), T("Показывать ваш ник")),
				Toggle("WmTariff", T("Тариф"), T("Показывать тариф")),
				{ Type = "slider", Name = T("Размер"), Desc = T("Ватермарка"), Group = T("Вид и позиция"), Min = 60, Max = 160,
					Get = function() return Settings.WmScale end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.WmScale = v
						Watermark.Relayout(true)
					end },
				{ Type = "cycle", Name = T("Позиция X"), Desc = T("Ватермарка"), Group = T("Вид и позиция"), Options = { T("Лево"), T("Центр"), T("Право") },
					Get = function() return Settings.WmH end,
					OnChange = function(i)
						Settings.WmH = i
						Watermark.Relayout(false)
					end },
				{ Type = "cycle", Name = T("Позиция Y"), Desc = T("Ватермарка"), Group = T("Вид и позиция"), Options = { T("Вверху"), T("Внизу") },
					Get = function() return Settings.WmV end,
					OnChange = function(i)
						Settings.WmV = i
						Watermark.Relayout(false)
					end },
			} },
			{ Title = T("Картинка"), Rows = {
				{ Type = "cycle", Name = T("Цветокоррекция"), Desc = T("Пресеты и кастом"), Options = names(GRADES),
					Get = function() return Settings.Grade end, OnChange = function(i) Env.SetGrade(i) end },
				{ Type = "color", Name = T("Цвет тона"), Desc = T("Для режима «Кастом.»"),
					When = function() return GRADES[Settings.Grade].Custom == true end,
					Get = function() return Settings.GradeTint end,
					OnChange = function(c)
						Settings.GradeTint = c
						Env.LiveGrade()
					end },
				Toggle("Atmosphere", T("Кино-свечение"), T("Bloom и блюр на скорости")),
				{ Type = "slider", Name = T("Блюр"), Desc = T("Сила на скорости"), Min = 0, Max = 100, Requires = { "Atmosphere" },
					Get = function() return Settings.BlurPower end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.BlurPower = v end },
				{ Type = "slider", Name = T("Свечение"), Desc = T("Сила bloom"), Min = 0, Max = 100, Requires = { "Atmosphere" },
					Get = function() return Settings.GlowPower end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.GlowPower = v
						Modules.Atmosphere.Refresh()
					end },
			} },
		},
	},
	{
		Title = T("КАМЕРА"),
		Columns = {
			{ Title = T("Камера"), Rows = {
				Toggle("Fov", T("Свой FOV"), T("Включить управление FOV")),
				{ Type = "slider", Name = T("Значение FOV"), Desc = "40 - 120", Min = 40, Max = 120, Requires = { "Fov" },
					Get = function() return Settings.Fov end, Format = function(v) return v .. "°" end,
					OnChange = function(v) Settings.Fov = v end },
				Toggle("Stretch", T("Растяг экрана"), T("Сжимает картинку по вертикали")),
				{ Type = "input", Name = T("Значение"), Desc = T("Растяг: 0.50 - 1.00"), Min = 0.5, Max = 1, Requires = { "Stretch" },
					Get = function() return Settings.StretchRes end, Format = function(v) return string.format("%.2f", v) end,
					OnChange = function(v) Settings.StretchRes = v end },
				Toggle("CameraBounce", T("Отставание камеры"), T("Плавно, не от 1 лица")),
				{ Type = "slider", Name = T("Сила"), Desc = T("Отставание камеры"), Min = 0, Max = 100, Requires = { "CameraBounce" },
					Get = function() return Settings.CamBounce end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.CamBounce = v end },
				Toggle("ForceThird", T("Всегда от 3 лица"), T("Работает в любой игре")),
				{ Type = "slider", Name = T("Дистанция"), Desc = T("Камера от 3 лица"), Min = 3, Max = 40, Requires = { "ForceThird" },
					Get = function() return Settings.ThirdDistance end, Format = function(v) return v .. T(" ст.") end,
					OnChange = function(v) Settings.ThirdDistance = v end },
				{ Type = "slider", Name = "FOV", Desc = T("FOV этой функции"), Min = 40, Max = 120, Requires = { "ForceThird" },
					Get = function() return Settings.ThirdFov end, Format = function(v) return v .. "°" end,
					OnChange = function(v) Settings.ThirdFov = v end },
				Toggle("CamPos", T("Смещение камеры"), T("Сдвиг камеры по X, Y и Z (не проходит сквозь стены)")),
				{ Type = "slider", Name = T("X · вправо"), Desc = T("Смещение камеры"), Min = -100, Max = 100, Requires = { "CamPos" },
					Get = function() return Settings.CamX end, Format = function(v) return string.format("%+.1f", v / 10) end,
					OnChange = function(v) Settings.CamX = v end },
				{ Type = "slider", Name = T("Y · вверх"), Desc = T("Смещение камеры"), Min = -50, Max = 150, Requires = { "CamPos" },
					Get = function() return Settings.CamY end, Format = function(v) return string.format("%+.1f", v / 10) end,
					OnChange = function(v) Settings.CamY = v end },
				{ Type = "slider", Name = T("Z · вперёд"), Desc = T("Смещение камеры"), Min = -100, Max = 100, Requires = { "CamPos" },
					Get = function() return Settings.CamZ end, Format = function(v) return string.format("%+.1f", v / 10) end,
					OnChange = function(v) Settings.CamZ = v end },
				{ Type = "button", Name = T("Сбросить камеру"), Desc = T("Смещение камеры"), Requires = { "CamPos" },
					OnClick = function()
						Settings.CamX, Settings.CamY, Settings.CamZ = 0, 0, 0
						Menu.CloseSettings()
					end },
				Toggle("FPerson", "FPerson", T("Видно своё тело от 1 лица")),
			} },
			{ Title = T("Прицел"), Rows = {
				Toggle("Crosshair", T("Прицел"), T("Крестик в стиле Minecraft")),
				{ Type = "slider", Name = T("Размер"), Desc = T("Прицел"), Min = 50, Max = 200, Requires = { "Crosshair" },
					Get = function() return Settings.CrosshairSize end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.CrosshairSize = v end },
				Toggle("CrosshairBox", T("Квадрат прицела"), T("Квадрат парит над поверхностью")),
				{ Type = "slider", Name = T("Размер"), Desc = T("Квадрат"), Min = 10, Max = 200, Requires = { "CrosshairBox" },
					Get = function() return Settings.BoxSize end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.BoxSize = v end },
				{ Type = "slider", Name = T("Альфа"), Desc = T("Прозрачность квадрата"), Min = 0, Max = 95, Requires = { "CrosshairBox" },
					Get = function() return Settings.BoxAlpha end, Format = function(v) return v .. "%" end,
					OnChange = function(v) Settings.BoxAlpha = v end },
			} },
		},
	},
	{
		Title = T("НАСТРОЙКИ"),
		Columns = {
			{ Title = T("Стиль"), Rows = {
				{ Type = "cycle", Name = T("Стиль меню"), Desc = T("Цвет интерфейса"), Options = names(UI_SKINS),
					Get = function() return Settings.UiSkin end,
					OnChange = function(i)
						Settings.UiSkin = i
						Skin.Apply(i, false)
					end },
				{ Type = "cycle", Name = T("Цвет эффектов"), Desc = T("Неон везде"), Options = names(Palette.Schemes),
					Get = function() return Palette.Index end,
					OnChange = function(i)
						Palette.Index = i
						Palette.Changed:Fire()
					end },
				{ Type = "cycle", Name = T("Сила ауры"), Desc = T("Частицы и свечение"), Options = names(AURA_LEVELS), Requires = { "Aura" },
					Get = function() return Settings.AuraLevel end,
					OnChange = function(i)
						Settings.AuraLevel = i
						if IsEnabled("Aura") then
							pcall(Modules.Aura.Disable)
							pcall(Modules.Aura.Enable)
						end
					end },
				{ Type = "cycle", Name = T("Масштаб меню"), Desc = T("Размер окна"), Options = { "80%", "100%", "120%" },
					Guard = function()
						if IsMobile then
							return false, T("Невозможно сменить масштаб на мобильном устройстве: доступно только 80%.")
						end
						return true
					end,
					Get = function() return Settings.UiScale end,
					OnChange = function(i)
						Settings.UiScale = i
						Menu.UpdateScale(false)
					end },
			} },
			{ Title = T("Система"), Rows = {
				Toggle("Sounds", T("Звуки"), T("Звуки интерфейса")),
				Toggle("Notifications", T("Уведомления"), T("Ошибки видны всегда")),
				{ Type = "cycle", Name = T("Время показа"), Desc = T("Уведомления"), Options = { T("3 сек"), T("5 сек"), T("8 сек") }, Requires = { "Notifications" },
					Get = function() return Settings.NotifyDurationIndex end,
					OnChange = function(i)
						Settings.NotifyDurationIndex = i
						CONFIG.NotifyDuration = NOTIFY_DURATIONS[i]
					end },
				{ Type = "slider", Name = T("Размер увед."), Desc = T("Уведомления"), Min = 60, Max = 150, Requires = { "Notifications" },
					Get = function() return Settings.NotifyScale end, Format = function(v) return v .. "%" end,
					OnChange = function(v)
						Settings.NotifyScale = v
						Notify.Relayout()
					end },
				{ Type = "cycle", Name = T("Увед.: X"), Desc = T("Позиция"), Options = { T("Лево"), T("Центр"), T("Право") }, Requires = { "Notifications" },
					Get = function() return Settings.NotifyH end,
					OnChange = function(i)
						Settings.NotifyH = i
						Notify.Relayout()
						Notify.Info(T("Так выглядят уведомления."), T("Позиция"), 2, true)
					end },
				{ Type = "cycle", Name = T("Увед.: Y"), Desc = T("Позиция"), Options = { T("Вверху"), T("Внизу") }, Requires = { "Notifications" },
					Get = function() return Settings.NotifyV end,
					OnChange = function(i)
						Settings.NotifyV = i
						Notify.Relayout()
						Notify.Info(T("Так выглядят уведомления."), T("Позиция"), 2, true)
					end },
				Toggle("AntiFling", "Anti Fling", T("Защита от выброса за карту")),
				{ Type = "button", Name = T("Тест уведомления"), Group = T("Тесты"), Desc = T("Информационное окно"), OnClick = test.Notification },
				{ Type = "button", Name = T("Тест ошибки"), Group = T("Тесты"), Desc = T("Шаблон с кодом"), OnClick = test.Error },
				{ Type = "button", Name = T("Тест тряски"), Group = T("Тесты"), Desc = T("Тряска камеры"), OnClick = test.Shake },
				{ Type = "button", Name = T("Тест молнии"), Group = T("Тесты"), Desc = T("Молния рядом с вами"), OnClick = test.Lightning },
				{ Type = "button", Name = T("Тест распада"), Group = T("Тесты"), Desc = T("Ваше тело рассыпется и вернётся"), OnClick = test.Decay },
				{ Type = "button", Name = T("Отключить всё"), Desc = T("Выключить визуальные модули"),
					OnClick = function()
						for id, feature in pairs(Features) do
							if feature.Enabled and not string.find(id, "^Wm") and id ~= "Sounds" and id ~= "Notifications" then
								SetFeature(id, false, true)
							end
						end
						Notify.Info(T("Все визуальные модули выключены."), T("Система"))
					end },
				{ Type = "button", Name = T("Выгрузить скрипт"), Desc = T("Убрать NN-Project полностью"),
					OnClick = function()
						task.defer(function()
							Unload(true) -- с прощальным сообщением
						end)
					end },
			} },
		},
	},
}

-- ---------------------------------------------------------------- пилюли, панели настроек, страницы
-- Из плоского списка строк SECTIONS собираются "элементы": переключатель (с настройками внутри панели),
-- кнопка, цикл (тап листает значение) или пилюля-панель (слайдеры, цвета, группы).
local ItemById = {}

local function depsMet(def)
	if def.Requires then
		local any = false
		for _, id in ipairs(def.Requires) do
			if IsEnabled(id) then
				any = true
				break
			end
		end
		if not any then
			return false
		end
	end
	if def.When and not def.When() then
		return false
	end
	return true
end

--- Серые (заблокированные) строки открытой панели и актуальные переключатели
function Menu.RefreshDeps()
	for _, entry in ipairs(UI.LiveDeps) do
		local met = depsMet(entry.Def)
		entry.Overlay.Active = not met
		Tween(entry.Overlay, TI.Fast, { BackgroundTransparency = met and 1 or 0.35 })
	end
	for id, paint in pairs(UI.LiveSwitches) do
		local feature = Features[id]
		if feature then
			paint(feature.Enabled, false)
		end
	end
end

function Menu.RefreshRows()
	Menu.CloseSettings()
	for _, fn in ipairs(UI.Pills) do
		pcall(fn)
	end
	Menu.RefreshDeps()
end

--- Включение / выключение функции (включение одного режима выключает "Exclusive" соседа)
function UI.ToggleFeature(def)
	local turningOn = not Features[def.Id].Enabled
	if turningOn and def.Exclusive then
		for _, other in ipairs(def.Exclusive) do
			SetFeature(other, false, true)
		end
	end
	SetFeature(def.Id, turningOn)
end

--- Следующее значение цикла (с проверкой Guard); возвращает текущий индекс или nil
function UI.Cycle(def)
	local nextIndex = def.Get() % #def.Options + 1
	if def.Guard then
		local allowed, reason = def.Guard(nextIndex)
		if not allowed then
			Notify.Error(reason, ERR.TEST, T("Недоступно"))
			return nil
		end
	end
	local ok, err = pcall(def.OnChange, nextIndex)
	if not ok then
		Notify.Error(T("Не удалось применить «") .. def.Name .. "».\n" .. tostring(err), ERR.TEST, T("Сбой настройки"))
	end
	Menu.RefreshDeps()
	return def.Get()
end

local function BuildItems(colDef, sectionTitle)
	local items, groups = {}, {}
	local lastSetting = nil
	for _, def in ipairs(colDef.Rows) do
		if def.Type == "toggle" then
			RegisterFeature(def.Id, def.Name, sectionTitle)
		end
		local parents = {}
		for _, id in ipairs(def.Requires or {}) do
			if ItemById[id] then
				parents[#parents + 1] = ItemById[id]
			end
		end
		if #parents > 0 then
			-- настройка живёт в панели функции, от которой зависит
			for _, parent in ipairs(parents) do
				parent.Rows[#parent.Rows + 1] = def
			end
		elseif def.When and lastSetting then
			lastSetting.Rows[#lastSetting.Rows + 1] = def
		elseif def.Type == "toggle" then
			local item = { Kind = "toggle", Def = def, Name = def.Name, Desc = def.Desc, Rows = {} }
			ItemById[def.Id] = item
			items[#items + 1] = item
			lastSetting = nil
		elseif def.Group then
			local item = groups[def.Group]
			if not item then
				item = { Kind = "panel", Name = def.Group, Rows = {} }
				groups[def.Group] = item
				items[#items + 1] = item
			end
			item.Rows[#item.Rows + 1] = def
			lastSetting = item
		elseif def.Type == "button" then
			items[#items + 1] = { Kind = "button", Def = def, Name = def.Name, Desc = def.Desc, Rows = {} }
			lastSetting = nil
		elseif def.Type == "cycle" then
			local item = { Kind = "cycle", Def = def, Name = def.Name, Desc = def.Desc, Rows = {} }
			items[#items + 1] = item
			lastSetting = item
		else
			local item = { Kind = "panel", Name = def.Name, Desc = def.Desc, Rows = { def } }
			items[#items + 1] = item
			lastSetting = item
		end
	end
	return items
end

-- ---------------------------------------------------------------- панель настроек (слева или справа от пилюли)
function Menu.CloseSettings()
	local current = UI.Settings
	if not current then
		return
	end
	UI.Settings = nil
	current.Close()
end

do
	local TextService = game:GetService("TextService")
	local PAD = 14
	local builders = {}

	local function rowHeight(def)
		if def.Type == "slider" then
			return 50
		elseif def.Type == "button" then
			return 34
		end
		return 32
	end

	function builders.toggle(row, def)
		local track = Create("Frame", {
			Name = "Switch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(40, 22),
			BorderSizePixel = 0, BackgroundColor3 = THEME.SwitchOff, Parent = row,
		}, { Corner(UDim.new(1, 0)) })
		local knob = Create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.Knob, BorderSizePixel = 0, Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		local function paint(state, instant)
			local pos = state and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
			local color = state and THEME.SwitchOn or THEME.SwitchOff
			if instant then
				knob.Position = pos
				track.BackgroundColor3 = color
			else
				Tween(knob, TI.Fast, { Position = pos })
				Tween(track, TI.Fast, { BackgroundColor3 = color })
			end
		end
		paint(Features[def.Id].Enabled, true)
		UI.LiveSwitches[def.Id] = paint
		local hit = Create("TextButton", {
			BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = row,
		})
		hit.Activated:Connect(function()
			UI.ToggleFeature(def)
		end)
	end

	function builders.slider(row, def, pm)
		local valueLabel = Create("TextLabel", {
			Name = "Value", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(90, 22),
			BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.AccentSoft,
			TextXAlignment = Enum.TextXAlignment.Right, Text = "", Parent = row,
		})
		local track = Create("Frame", {
			Name = "Track", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0, 36), Size = UDim2.new(1, 0, 0, 6),
			BorderSizePixel = 0, BackgroundColor3 = THEME.SwitchOff, Parent = row,
		}, { Corner(UDim.new(1, 0)) })
		local fill = Create("Frame", {
			Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, BackgroundColor3 = THEME.SwitchOn, Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		local knob = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = THEME.AccentSoft, BorderSizePixel = 0, ZIndex = 2, Parent = track,
		}, { Corner(UDim.new(1, 0)) })
		local hit = Create("TextButton", {
			BackgroundTransparency = 1, Text = "", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -8, 0, 36),
			Size = UDim2.new(1, 16, 0, 30), ZIndex = 3, Parent = row,
		})

		local function setValue(v, fire)
			local alpha = (v - def.Min) / (def.Max - def.Min)
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
			valueLabel.Text = def.Format and def.Format(v) or tostring(v)
			if fire then
				local ok, err = pcall(def.OnChange, v)
				if not ok then
					warn("[NN-Project] slider: " .. tostring(err))
				end
			end
		end
		setValue(def.Get(), false)

		local dragging = false
		local function fromX(x)
			local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
			setValue(math.floor(def.Min + a * (def.Max - def.Min) + 0.5), true)
		end
		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				fromX(input.Position.X)
				local conn
				conn = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						conn:Disconnect()
					end
				end)
			end
		end)
		pm:Give(UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				fromX(input.Position.X)
			end
		end))
	end

	function builders.cycle(row, def)
		local button = Create("TextButton", {
			Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(108, 26),
			BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = THEME.AccentSoft,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = def.Options[def.Get()], BackgroundColor3 = THEME.GlassDeep, Parent = row,
		}, { Corner(UDim.new(1, 0)), Create("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }) })
		button.Activated:Connect(function()
			local value = UI.Cycle(def)
			if value then
				button.Text = def.Options[value]
				button.BackgroundColor3 = THEME.SwitchOn
				Tween(button, TI.Slow, { BackgroundColor3 = THEME.GlassDeep })
			end
		end)
	end

	function builders.color(row, def)
		local swatch = Create("TextButton", {
			Name = "Swatch", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(26, 26),
			BorderSizePixel = 0, AutoButtonColor = false, Text = "", BackgroundColor3 = def.Get(), Parent = row,
		}, { Corner(UDim.new(1, 0)), Create("UIStroke", { Color = THEME.Text, Thickness = 1, Transparency = 0.6 }) })
		swatch.Activated:Connect(function()
			OpenColorPicker(def.Get(), function(color)
				def.OnChange(color)
				swatch.BackgroundColor3 = def.Get()
			end)
		end)
	end

	function builders.input(row, def)
		local box = Create("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(84, 26), BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = THEME.Text, ClearTextOnFocus = false, Text = "",
			BackgroundColor3 = THEME.GlassDeep, Parent = row,
		}, { Corner(UDim.new(1, 0)) })
		local function paint()
			box.Text = def.Format and def.Format(def.Get()) or tostring(def.Get())
		end
		paint()
		box.FocusLost:Connect(function()
			local v = tonumber((box.Text:gsub(",", ".")))
			if v then
				v = math.floor(math.clamp(v, def.Min, def.Max) * 100 + 0.5) / 100
				local ok, err = pcall(def.OnChange, v)
				if not ok then
					warn("[NN-Project] input: " .. tostring(err))
				end
			end
			paint()
		end)
	end

	function builders.button(row, def)
		local button = Create("TextButton", {
			Name = "Action", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, AutoButtonColor = false, Font = Enum.Font.GothamMedium,
			TextSize = 13, TextColor3 = THEME.Text, Text = def.Name, BackgroundColor3 = THEME.GlassDeep, Parent = row,
		}, { Corner(UDim.new(1, 0)) })
		button.Activated:Connect(function()
			button.BackgroundColor3 = THEME.SwitchOn
			Tween(button, TI.Slow, { BackgroundColor3 = THEME.GlassDeep })
			local ok, err = pcall(def.OnClick)
			if not ok then
				Notify.Error(T("Не удалось выполнить действие «") .. def.Name .. "».\n" .. tostring(err), ERR.TEST, T("Сбой действия"))
			end
		end)
	end

	local function makeRow(parent, def, y, pm)
		local h = rowHeight(def)
		local row = Create("Frame", {
			Name = "Row", Position = UDim2.fromOffset(PAD, y), Size = UDim2.new(1, -PAD * 2, 0, h), BackgroundTransparency = 1, Parent = parent,
		})
		if def.Type ~= "button" then
			Create("TextLabel", {
				Name = "Name", BackgroundTransparency = 1, Size = UDim2.new(1, -112, 0, def.Type == "slider" and 22 or h),
				Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd, Text = def.Name, Parent = row,
			})
		end
		local build = builders[def.Type] or builders.cycle
		build(row, def, pm)
		if def.Requires or def.When then
			local met = depsMet(def)
			local overlay = Create("Frame", {
				Name = "Disabled", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 6, Active = not met,
				BackgroundColor3 = THEME.GlassDeep, BackgroundTransparency = met and 1 or 0.35, Parent = row,
			}, { Corner(UDim.new(0, 10)) })
			UI.LiveDeps[#UI.LiveDeps + 1] = { Overlay = overlay, Def = def }
		end
	end

	function Menu.OpenSettings(item, anchor)
		Menu.CloseSettings()
		ClosePopup()
		UI.LiveDeps = {}
		UI.LiveSwitches = {}

		local rows = item.Rows
		local toggleDef = item.Kind == "toggle" and item.Def or nil
		local footer = (item.Desc and item.Desc ~= "") and item.Desc or nil
		local footerH = 0
		if footer then
			local ok, size = pcall(function()
				return TextService:GetTextSize(footer, 12, Enum.Font.Gotham, Vector2.new(UI.PanelW - PAD * 2 - 8, 400))
			end)
			footerH = (ok and size.Y or 30) + 6
		end

		local y = PAD + 30 + 10
		local placed = {}
		for _, def in ipairs(rows) do
			placed[#placed + 1] = { Def = def, Y = y }
			y = y + rowHeight(def) + 6
		end
		local footerY = y
		if footer then
			y = y + footerH
		end
		local height = y + PAD - 4

		-- позиция: слева от пилюли, а если места нет - справа
		local k = math.max(UI.Scale * UI.Pop.Scale, 0.01)
		local rel = (anchor.AbsolutePosition - Content.AbsolutePosition) / k
		local cw, ch = Content.AbsoluteSize.X / k, Content.AbsoluteSize.Y / k
		local centerY = rel.Y + UI.PillH / 2
		local leftX = rel.X - 26 - UI.PanelW
		local onLeft = leftX >= 8
		local x = onLeft and leftX or (rel.X + UI.PillW + 26)
		x = math.clamp(x, 8, math.max(cw - UI.PanelW - 8, 8))
		local top = math.clamp(centerY - height / 2, 8, math.max(ch - height - 8, 8))

		local pm = Maid.new()
		local catcher = Create("TextButton", {
			Name = "SettingsCatcher", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
			Size = UDim2.fromScale(1, 1), ZIndex = 20, Parent = Content,
		})
		local panel = Create("Frame", {
			Name = "Settings", Position = UDim2.fromOffset(x + (onLeft and 10 or -10), top), Size = UDim2.fromOffset(UI.PanelW, height),
			BackgroundColor3 = THEME.Glass, BorderSizePixel = 0, ZIndex = 21, Active = true, Parent = Content,
		}, { Corner(UDim.new(0, 26)), Create("UIStroke", { Color = THEME.Stroke, Thickness = 1, Transparency = 0.45 }) })
		Tween(panel, TI.Fast, { Position = UDim2.fromOffset(x, top) })

		-- указатель-треугольник от пилюли к панели (из горизонтальных полосок)
		local triX = onLeft and (rel.X - 20) or (rel.X + UI.PillW + 11)
		local triY = math.clamp(centerY - 8, top + 18, top + height - 34)
		local tri = Create("Frame", {
			Name = "Pointer", BackgroundTransparency = 1, Size = UDim2.fromOffset(9, 16), Position = UDim2.fromOffset(triX, triY),
			ZIndex = 21, Parent = Content,
		})
		for i = 0, 15 do
			local dist = math.abs(i + 0.5 - 8) / 8
			local w = math.max(1, math.floor(9 * (1 - dist) + 0.5))
			Create("Frame", {
				AnchorPoint = Vector2.new(onLeft and 1 or 0, 0), Position = UDim2.new(onLeft and 1 or 0, 0, 0, i),
				Size = UDim2.fromOffset(w, 1), BackgroundColor3 = THEME.Indicator, BorderSizePixel = 0, ZIndex = 21, Parent = tri,
			})
		end

		-- полоса с названием (и переключателем функции)
		local band = Create("Frame", {
			Name = "Band", Position = UDim2.fromOffset(0, PAD), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = THEME.GlassDeep,
			BorderSizePixel = 0, Parent = panel,
		})
		Create("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 0), Size = UDim2.new(1, -(PAD * 2 + (toggleDef and 52 or 0)), 1, 0),
			Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.Text, TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd, Text = item.Name, Parent = band,
		})
		if toggleDef then
			local host = Create("Frame", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD, 0), Size = UDim2.new(1, -PAD * 2, 1, 0), Parent = band,
			})
			builders.toggle(host, toggleDef)
		end

		for _, entry in ipairs(placed) do
			makeRow(panel, entry.Def, entry.Y, pm)
		end
		if footer then
			Create("TextLabel", {
				Name = "Desc", BackgroundTransparency = 1, Position = UDim2.fromOffset(PAD + 4, footerY), Size = UDim2.new(1, -(PAD * 2 + 8), 0, footerH),
				Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = THEME.Muted, Text = footer, Parent = panel,
			})
		end

		local closed = false
		UI.Settings = {
			Close = function()
				if closed then
					return
				end
				closed = true
				pm:Clean()
				UI.LiveDeps = {}
				UI.LiveSwitches = {}
				catcher:Destroy()
				panel:Destroy()
				tri:Destroy()
			end,
		}
		catcher.Activated:Connect(function()
			Menu.CloseSettings()
		end)
	end
end

-- ---------------------------------------------------------------- пилюля
local function BuildPill(parent, item, order)
	local def, kind = item.Def, item.Kind
	local hasRows = #item.Rows > 0
	local pill = Create("TextButton", {
		Name = "Pill", LayoutOrder = order, AutoButtonColor = false, Text = "", BorderSizePixel = 0,
		Size = UDim2.fromOffset(UI.PillW, UI.PillH), BackgroundColor3 = THEME.Glass, Parent = parent,
	}, { Corner(UDim.new(1, 0)) })
	local hover = Create("Frame", {
		Name = "Hover", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1,
		BorderSizePixel = 0, Parent = pill,
	}, { Corner(UDim.new(1, 0)) })
	local padding = { Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, hasRows and 28 or 16) }) }
	local label = Create("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, kind == "cycle" and -7 or 0),
		Font = Enum.Font.GothamMedium, TextSize = kind == "cycle" and 14 or 15, TextColor3 = THEME.Text,
		TextTruncate = Enum.TextTruncate.AtEnd, Text = item.Name, Parent = pill,
	}, padding)
	local sub = nil
	if kind == "cycle" then
		sub = Create("TextLabel", {
			Name = "Sub", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 9),
			Font = Enum.Font.Gotham, TextSize = 11, TextColor3 = THEME.AccentSoft, TextTruncate = Enum.TextTruncate.AtEnd,
			Text = def.Options[def.Get()], Parent = pill,
		}, { Create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, hasRows and 28 or 16) }) })
	end
	if hasRows then
		for i = 0, 2 do
			Create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12 - i * 7, 0.5, 0), Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = THEME.Text, BackgroundTransparency = 0.6, BorderSizePixel = 0, Parent = pill,
			}, { Corner(UDim.new(1, 0)) })
		end
	end

	local isOn = false
	local function setState(state, instant)
		isOn = state
		local color = state and THEME.GlassOn or THEME.Glass
		if instant then
			pill.BackgroundColor3 = color
		else
			Tween(pill, TI.Fast, { BackgroundColor3 = color })
		end
	end
	Skin.OnChange(function()
		setState(isOn, false)
		if sub then
			sub.TextColor3 = THEME.AccentSoft
		end
	end)

	if kind == "toggle" then
		Features[def.Id].UI = { Set = setState }
		setState(Features[def.Id].Enabled, true)
		UI.Pills[#UI.Pills + 1] = function()
			setState(Features[def.Id].Enabled, true)
		end
	elseif kind == "cycle" then
		UI.Pills[#UI.Pills + 1] = function()
			sub.Text = def.Options[def.Get()]
		end
	end

	local function flash()
		hover.BackgroundTransparency = 0.8
		Tween(hover, TI.Slow, { BackgroundTransparency = 1 })
	end
	pill.MouseEnter:Connect(function()
		Tween(hover, TI.Fast, { BackgroundTransparency = 0.92 })
	end)
	pill.MouseLeave:Connect(function()
		Tween(hover, TI.Fast, { BackgroundTransparency = 1 })
	end)

	-- собственный обработчик ввода (Activated внутри ScrollingFrame на телефоне срабатывает нестабильно)
	local function tap()
		if kind == "toggle" then
			UI.ToggleFeature(def)
		elseif kind == "button" then
			flash()
			local ok, err = pcall(def.OnClick)
			if not ok then
				Notify.Error(T("Не удалось выполнить действие «") .. def.Name .. "».\n" .. tostring(err), ERR.TEST, T("Сбой действия"))
			end
		elseif kind == "cycle" then
			flash()
			local value = UI.Cycle(def)
			if value then
				sub.Text = def.Options[value]
			end
		else
			Menu.OpenSettings(item, pill)
		end
	end

	-- тап по пилюле: действие; тап по трём точкам справа: настройки (удержания нет)
	pill.InputBegan:Connect(function(input)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton2 then
			Menu.OpenSettings(item, pill)
			return
		end
		if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
			return
		end
		local startPos = input.Position
		local pixelsPerUnit = pill.AbsoluteSize.X / UI.PillW
		local inDots = hasRows and (startPos.X - pill.AbsolutePosition.X) > pill.AbsoluteSize.X - 46 * pixelsPerUnit
		local handled = false -- палец сдвинулся (это прокрутка) или нажатие уже обработано
		local conn
		Tween(hover, TI.Fast, { BackgroundTransparency = 0.86 })
		conn = input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then
				conn:Disconnect()
				Tween(hover, TI.Fast, { BackgroundTransparency = 1 })
				if not handled then
					handled = true
					if inDots then
						Menu.OpenSettings(item, pill)
					else
						tap()
					end
				end
			elseif not handled and (input.Position - startPos).Magnitude > UI.MoveSlop then
				handled = true
				Tween(hover, TI.Fast, { BackgroundTransparency = 1 })
			end
		end)
	end)
	return pill
end

-- ---------------------------------------------------------------- страницы по 4 колонки + навигация
local PagesArea = Create("Frame", {
	Name = "Pages", Position = UDim2.fromOffset(0, UI.TopH), Size = UDim2.new(1, 0, 1, -(UI.TopH + UI.BottomH)),
	BackgroundTransparency = 1, ClipsDescendants = true, Parent = Content,
})

do
	local columns = {}
	for _, section in ipairs(SECTIONS) do
		for _, colDef in ipairs(section.Columns) do
			columns[#columns + 1] = { Def = colDef, Section = section.Title }
		end
	end
	for _, col in ipairs(columns) do
		col.Items = BuildItems(col.Def, col.Section)
	end

	local pageCount = math.ceil(#columns / 4)
	for p = 1, pageCount do
		local page = Create("Frame", {
			Name = "Page_" .. p, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = p == 1, Parent = PagesArea,
		})
		UI.Pages[p] = page
		local scroll = Create("ScrollingFrame", {
			Name = "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = page,
		})
		local row = Create("Frame", {
			Name = "Row", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 200), AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, UI.ColGap),
			}),
			Create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }),
		})
		UI.RowFrames[p] = row

		for i = 1, 4 do
			local col = columns[(p - 1) * 4 + i]
			if col then
				local column = Create("CanvasGroup", {
					Name = "Column", LayoutOrder = i, Size = UDim2.fromOffset(UI.PillW, 0), AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundTransparency = 1, GroupTransparency = 1, Parent = row,
				}, {
					Create("UIListLayout", {
						SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0, UI.PillGap),
					}),
				})
				UI.Fade[#UI.Fade + 1] = { Group = column, Delay = 0.1 + (i - 1) * 0.07 }
				Create("TextLabel", {
					Name = "Header", LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1,
					Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = THEME.Text, Text = col.Def.Title, Parent = column,
				})
				for order, item in ipairs(col.Items) do
					BuildPill(column, item, order)
				end
			end
		end
	end
end

-- подвал (точки страниц и нижние пилюли) - одним блоком для фейда
UI.Footer = Create("CanvasGroup", {
	Name = "Footer", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(260, 112),
	BackgroundTransparency = 1, GroupTransparency = 1, Parent = Content,
})
UI.Fade[#UI.Fade + 1] = { Group = UI.Footer, Delay = 0.4 }

-- логотип NN в правом верхнем углу (как в ватермарке) и "P R O J E C T" под ним (как в интро)
do
	local group = Create("CanvasGroup", {
		Name = "LogoGroup", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 22), Size = UDim2.fromOffset(84, 70),
		BackgroundTransparency = 1, GroupTransparency = 1, Parent = Content,
	})
	UI.Fade[#UI.Fade + 1] = { Group = group, Delay = 0.05 }
	local holder = Create("Frame", { Name = "LogoHolder", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), BackgroundTransparency = 1, Parent = group })
	holder.Size = BuildLogo(holder, 34, Color3.fromRGB(246, 240, 255)).Size
	Create("TextLabel", {
		Name = "Project", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 44), Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 10, TextColor3 = THEME.Text, Text = "P R O J E C T", Parent = group,
	})

	-- Пасхалка: 10 нажатий подряд на логотип. Работает только в русской версии скрипта.
	local pop = Create("UIScale", { Name = "Pop", Parent = group })
	local button = Create("TextButton", {
		Name = "LogoButton", BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = group,
	})
	local taps, lastTap = 0, 0
	OnTap(button, function()
		local now = os.clock()
		if now - lastTap > 2.5 then
			taps = 0 -- пауза дольше 2.5 секунд сбрасывает счёт
		end
		lastTap = now
		taps += 1
		if Lang ~= "RUS" then
			return
		end
		if taps >= 10 then
			taps = 0
			PlayAsset(101685860155742, 1, 12)
			Notify.Custom("Pupue!", "опа посхалка", "ты слишком крут🥶", 6)
			pop.Scale = 1.4
			Tween(pop, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		else
			pop.Scale = 1.1
			Tween(pop, TI.Fast, { Scale = 1 })
		end
	end)
end

-- кнопка "Закрыть" в левом нижнем углу: ватермарка может перекрывать нижние кнопки, а закрыть меню нужно всегда
do
	local group = Create("CanvasGroup", {
		Name = "CloseGroup", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -32), Size = UDim2.fromOffset(110, 30),
		BackgroundTransparency = 1, GroupTransparency = 1, Parent = Content,
	})
	UI.Fade[#UI.Fade + 1] = { Group = group, Delay = 0.4 }
	local button = Make("TextButton", {
		Name = "Close", Size = UDim2.fromScale(1, 1), AutoButtonColor = false, BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
		TextSize = 14, TextColor3 = THEME.Text, Text = T("Закрыть"), Skin = { BackgroundColor3 = "Glass" }, Parent = group,
	}, { Corner(UDim.new(1, 0)) })
	local hover = Create("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = button,
	}, { Corner(UDim.new(1, 0)) })
	button.MouseEnter:Connect(function()
		Tween(hover, TI.Fast, { BackgroundTransparency = 0.92 })
	end)
	button.MouseLeave:Connect(function()
		Tween(hover, TI.Fast, { BackgroundTransparency = 1 })
	end)
	OnTap(button, function()
		Menu.Close()
	end)
end

-- навигация: стрелки и точки страниц над нижними кнопками
do
	local count = #UI.Pages
	local nav = Create("Frame", {
		Name = "Nav", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -(14 + 66 + 8)),
		Size = UDim2.fromOffset(120 + count * 18, 24), BackgroundTransparency = 1, Parent = UI.Footer,
	})
	local function arrow(dir)
		local button = Create("TextButton", {
			Name = dir < 0 and "Prev" or "Next", AnchorPoint = Vector2.new(dir < 0 and 0 or 1, 0.5), Position = UDim2.new(dir < 0 and 0 or 1, 0, 0.5, 0),
			Size = UDim2.fromOffset(34, 24), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = nav,
		})
		for _, def in ipairs({ { -3.5, 40 * dir }, { 3.5, -40 * dir } }) do
			Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -dir * 1.5, 0.5, def[1]), Size = UDim2.fromOffset(10, 2),
				Rotation = def[2], BorderSizePixel = 0, BackgroundColor3 = THEME.Text, Parent = button,
			})
		end
		OnTap(button, function()
			Menu.SelectTab(math.clamp(UI.Current + dir, 1, count))
		end)
	end
	arrow(-1)
	arrow(1)
	for i = 1, count do
		local hit = Create("TextButton", {
			Name = "Dot_" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (i - (count + 1) / 2) * 18, 0.5, 0),
			Size = UDim2.fromOffset(18, 24), BackgroundTransparency = 1, AutoButtonColor = false, Text = "", Parent = nav,
		})
		local dot = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BorderSizePixel = 0,
			BackgroundColor3 = THEME.Text, BackgroundTransparency = 0.7, Parent = hit,
		}, { Corner(UDim.new(1, 0)) })
		UI.Dots[i] = dot
		OnTap(hit, function()
			Menu.SelectTab(i)
		end)
	end
end

function UI.PaintDots()
	for i, dot in ipairs(UI.Dots) do
		local active = i == UI.Current
		Tween(dot, TI.Fast, {
			BackgroundTransparency = active and 0 or 0.7,
			BackgroundColor3 = active and THEME.AccentSoft or THEME.Text,
			Size = active and UDim2.fromOffset(10, 10) or UDim2.fromOffset(8, 8),
		})
	end
end
Skin.OnChange(function()
	UI.PaintDots()
end)

function Menu.SelectTab(index, instant)
	index = math.clamp(index, 1, #UI.Pages)
	if index == UI.Current and not instant then
		return
	end
	Menu.CloseSettings()
	ClosePopup()
	UI.Token += 1
	local token = UI.Token
	local old, new = UI.Pages[UI.Current], UI.Pages[index]
	local direction = index > UI.Current and 1 or -1
	UI.Current = index
	UI.PaintDots()
	if instant or old == new then
		for _, page in ipairs(UI.Pages) do
			page.Visible = page == new
			page.Position = UDim2.fromOffset(0, 0)
		end
		return
	end
	new.Position = UDim2.new(direction, 0, 0, 0)
	new.Visible = true
	Tween(new, TI.Medium, { Position = UDim2.fromOffset(0, 0) })
	Tween(old, TI.Medium, { Position = UDim2.new(-direction, 0, 0, 0) })
	task.delay(0.4, function()
		if token ~= UI.Token then
			return
		end
		for _, page in ipairs(UI.Pages) do
			if page ~= new then
				page.Visible = false
				page.Position = UDim2.fromOffset(0, 0)
			end
		end
	end)
end

-- ---------------------------------------------------------------- окна "Конфиги" и "О скрипте" (по центру, поверх меню)
do
	local CARD_W, CARD_H = 520, 292

	local function BuildModal(name, title)
		local overlay = Create("TextButton", {
			Name = name .. "Overlay", AutoButtonColor = false, Text = "", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1,
			BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 30, Parent = Content,
		})
		local card = Make("CanvasGroup", {
			Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 26), Size = UDim2.fromOffset(CARD_W, CARD_H),
			BorderSizePixel = 0, GroupTransparency = 1, Active = true, Skin = { BackgroundColor3 = "Glass" }, Parent = overlay,
		}, { Corner(UDim.new(0, 28)), Make("UIStroke", { Thickness = 1, Transparency = 0.4, Skin = { Color = "Stroke" } }) })
		local state = { Open = false, Card = card }

		function state.Set(open)
			if open == state.Open then
				return
			end
			state.Open = open
			Menu.CloseSettings()
			ClosePopup()
			if open then
				for _, other in pairs(UI.Modals) do
					if other ~= state and other.Open then
						other.Set(false)
					end
				end
				overlay.Visible = true
				card.Position = UDim2.new(0.5, 0, 0.5, 26)
				Tween(overlay, TI.Fast, { BackgroundTransparency = 0.45 })
				Tween(card, TI.Medium, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0) })
			else
				Tween(overlay, TI.Fast, { BackgroundTransparency = 1 })
				local tw = Tween(card, TI.Fast, { GroupTransparency = 1, Position = UDim2.new(0.5, 0, 0.5, 26) })
				tw.Completed:Connect(function()
					if not state.Open then
						overlay.Visible = false
					end
				end)
			end
		end
		overlay.Activated:Connect(function()
			state.Set(false)
		end)

		Create("TextLabel", {
			Name = "Title", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(240, 24),
			BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = THEME.Text, Text = title, Parent = card,
		})
		local back = Make("TextButton", {
			Name = "Back", BackgroundTransparency = 1, AutoButtonColor = false, Position = UDim2.fromOffset(20, 14), Size = UDim2.fromOffset(80, 24),
			Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Text = T("   Назад"),
			Skin = { TextColor3 = "AccentSoft" }, Parent = card,
		})
		for _, rot in ipairs({ -40, 40 }) do
			Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(5, rot < 0 and 8 or 16), Size = UDim2.fromOffset(8, 2),
				Rotation = rot, BorderSizePixel = 0, BackgroundColor3 = THEME.AccentSoft, Parent = back,
			})
		end
		back.Activated:Connect(function()
			state.Set(false)
		end)
		UI.Modals[name] = state
		return card, state
	end

	-- ---- "О скрипте"
	do
		local card, state = BuildModal("AboutPanel", T("О скрипте"))
		local scroll = Make("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 52), Size = UDim2.new(1, -48, 1, -64),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
			Skin = { ScrollBarImageColor3 = "Indicator" }, Parent = card,
		}, { Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }) })

		local order = 0
		local function line(text, size, font, skinKey, height)
			order += 1
			return Make("TextLabel", {
				LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or size + 6), Font = font,
				TextSize = size, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Text = text,
				TextColor3 = THEME.Text, Skin = skinKey and { TextColor3 = skinKey } or nil, Parent = scroll,
			})
		end
		line(T("Версия ") .. CONFIG.Version .. (CONFIG.Patch ~= "" and (" F" .. CONFIG.Patch) or "") .. " | " .. CONFIG.Generation, 13, Enum.Font.Gotham, "Muted", 18)
		line(T("Разработчики"), 15, Enum.Font.GothamBold, nil, 24)
		for _, name in ipairs({ "Claude Sonnet 5.5", "ChatGPT", T("великий китаец DeepSeek"), "vio.dev", "KonataTrue", T("Gemini (с деменцией)") }) do
			line("•  " .. name, 14, Enum.Font.GothamMedium, nil, 20)
		end
		line(T("ВСЕ ПРАВА ЗАЩИЩЕНЫ ВЛАДЕЛЬЦЕМ vio.dev"), 12, Enum.Font.GothamBold, "Muted", 30)
		Menu.SetAbout = state.Set
	end

	-- ---- "Конфиги": список, сохранить / загрузить / переписать / удалить (с подтверждением)
	do
		local panel, state = BuildModal("ConfigPanel", T("Конфиги"))
		local selected = nil

		local list = Make("ScrollingFrame", {
			Name = "List", BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(24, 52), Size = UDim2.fromOffset(246, 216),
			CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
			Skin = { ScrollBarImageColor3 = "Indicator" }, Parent = panel,
		}, {
			Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 5) }),
			Create("UIPadding", { PaddingRight = UDim.new(0, 6) }),
		})
		local emptyLabel = Make("TextLabel", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(24, 60), Size = UDim2.fromOffset(246, 40), Font = Enum.Font.Gotham,
			TextSize = 13, Text = T("Конфигов пока нет. Введите имя справа и нажмите «Сохранить»."), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Skin = { TextColor3 = "Muted" }, Parent = panel,
		})

		local function refreshList()
			for _, child in ipairs(list:GetChildren()) do
				if child:IsA("TextButton") then
					child:Destroy()
				end
			end
			local names = Config.List()
			emptyLabel.Visible = #names == 0
			if selected and not table.find(names, selected) then
				selected = nil
			end
			for i, name in ipairs(names) do
				local item = Create("TextButton", {
					LayoutOrder = i, Size = UDim2.new(1, 0, 0, 34), BorderSizePixel = 0, AutoButtonColor = false,
					Font = Enum.Font.GothamMedium, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Text = name,
					BackgroundColor3 = name == selected and THEME.GlassOn or THEME.GlassDeep,
					TextColor3 = THEME.Text, Parent = list,
				}, { Corner(UDim.new(1, 0)), Create("UIPadding", { PaddingLeft = UDim.new(0, 14) }) })
				item.Activated:Connect(function()
					selected = name
					refreshList()
				end)
			end
		end
		state.Refresh = refreshList

		-- окно подтверждения поверх панели
		local function confirm(text, onYes)
			local dim = Create("TextButton", {
				BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.5, Text = "", AutoButtonColor = false,
				Size = UDim2.fromScale(1, 1), ZIndex = 30, Parent = panel,
			})
			local card = Create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(300, 130), BorderSizePixel = 0,
				ZIndex = 31, BackgroundColor3 = THEME.Glass, Parent = dim,
			}, { Corner(UDim.new(0, 20)), Create("UIStroke", { Color = THEME.Stroke, Thickness = 1, Transparency = 0.3 }) })
			Create("TextLabel", {
				BackgroundTransparency = 1, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 56), Font = Enum.Font.GothamMedium,
				TextSize = 14, TextColor3 = THEME.Text, TextWrapped = true, Text = text, ZIndex = 32, Parent = card,
			})
			local function btn(label, x, accent)
				return Create("TextButton", {
					Position = UDim2.fromOffset(x, 80), Size = UDim2.fromOffset(126, 34), BorderSizePixel = 0, AutoButtonColor = false,
					Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text, Text = label, ZIndex = 32,
					BackgroundColor3 = accent and THEME.SwitchOn or THEME.GlassDeep, Parent = card,
				}, { Corner(UDim.new(1, 0)) })
			end
			local yes, no = btn(T("Да"), 16, true), btn(T("Отмена"), 158, false)
			yes.Activated:Connect(function()
				dim:Destroy()
				onYes()
			end)
			no.Activated:Connect(function()
				dim:Destroy()
			end)
		end

		local function guarded(fn)
			local ok, err = pcall(fn)
			if not ok then
				Notify.Error(tostring(err), "NN-E301", T("Конфиги"))
			end
		end

		-- правая колонка: имя нового конфига и кнопки
		Make("TextBox", {
			Name = "NameBox", Position = UDim2.fromOffset(290, 52), Size = UDim2.fromOffset(206, 34), BorderSizePixel = 0, Font = Enum.Font.GothamMedium,
			TextSize = 13, TextColor3 = THEME.Text, PlaceholderText = T("Имя нового конфига"), ClearTextOnFocus = false, Text = "",
			BackgroundColor3 = THEME.GlassDeep, Parent = panel,
		}, { Corner(UDim.new(1, 0)), Create("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }) })
		local nameBox = panel.NameBox

		local function actionButton(text, y, accent, callback)
			local b = Create("TextButton", {
				Position = UDim2.fromOffset(290, y), Size = UDim2.fromOffset(206, 36), BorderSizePixel = 0, AutoButtonColor = false,
				Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = THEME.Text, Text = text,
				BackgroundColor3 = accent and THEME.SwitchOn or THEME.GlassDeep, Parent = panel,
			}, { Corner(UDim.new(1, 0)) })
			b.Activated:Connect(function()
				guarded(callback)
			end)
			return b
		end

		local function needSelected()
			if not selected then
				error(T("Сначала выберите конфиг в списке."))
			end
			return selected
		end

		actionButton(T("Сохранить"), 96, true, function()
			local name = Config.Sanitize(nameBox.Text)
			if name == "" then
				name = "config_" .. (#Config.List() + 1)
			end
			if Config.Exists(name) then
				error(T("Конфиг «") .. name .. T("» уже есть. Выберите его и нажмите «Переписать»."))
			end
			Config.Write(name, Config.Collect())
			nameBox.Text = ""
			selected = name
			refreshList()
			Notify.Info(T("Конфиг «") .. name .. T("» сохранён."), T("Конфиги"))
		end)
		actionButton(T("Загрузить"), 140, false, function()
			local name = needSelected()
			Config.Apply(Config.Read(name))
			Notify.Info(T("Конфиг «") .. name .. T("» загружен."), T("Конфиги"))
		end)
		actionButton(T("Переписать"), 184, false, function()
			local name = needSelected()
			confirm(T("Переписать конфиг «") .. name .. T("» текущими настройками?"), function()
				guarded(function()
					Config.Write(name, Config.Collect())
					Notify.Info(T("Конфиг «") .. name .. T("» переписан."), T("Конфиги"))
				end)
			end)
		end)
		actionButton(T("Удалить"), 228, false, function()
			local name = needSelected()
			confirm(T("Удалить конфиг «") .. name .. T("»? Это нельзя отменить."), function()
				guarded(function()
					Config.Delete(name)
					selected = nil
					refreshList()
					Notify.Info(T("Конфиг «") .. name .. T("» удалён."), T("Конфиги"))
				end)
			end)
		end)
	end
end

-- ---------------------------------------------------------------- нижние пилюли: "Конфиги" и "О скрипте"
do
	local bottom = Create("Frame", {
		Name = "Bottom", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(190, 66),
		BackgroundTransparency = 1, Parent = UI.Footer,
	}, {
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }),
	})
	local function bottomPill(text, order, callback)
		local button = Make("TextButton", {
			Name = "Bottom_" .. order, LayoutOrder = order, Size = UDim2.fromOffset(190, 30), AutoButtonColor = false, BorderSizePixel = 0,
			Font = Enum.Font.GothamMedium, TextSize = 14, TextColor3 = THEME.Text, Text = text, Skin = { BackgroundColor3 = "Glass" }, Parent = bottom,
		}, { Corner(UDim.new(1, 0)) })
		local hover = Create("Frame", {
			Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = button,
		}, { Corner(UDim.new(1, 0)) })
		button.MouseEnter:Connect(function()
			Tween(hover, TI.Fast, { BackgroundTransparency = 0.92 })
		end)
		button.MouseLeave:Connect(function()
			Tween(hover, TI.Fast, { BackgroundTransparency = 1 })
		end)
		OnTap(button, callback)
	end
	bottomPill(T("Конфиги"), 1, function()
		local state = UI.Modals.ConfigPanel
		if not state.Open then
			state.Refresh()
			if not Config.HasFiles then
				Notify.Info(T("Файловая система недоступна: конфиги хранятся только до перезахода в игру."), T("Конфиги"), 6)
			end
		end
		state.Set(not state.Open)
	end)
	bottomPill(T("О скрипте"), 2, function()
		local state = UI.Modals.AboutPanel
		state.Set(not state.Open)
	end)
end

Menu.UpdateScale(true)

-- ---------------------------------------------------------------- открытие / закрытие
--- Блоки меню проявляются по очереди (шапка, колонки слева направо, подвал)
function UI.FadeIn()
	UI.FadeToken += 1
	local token = UI.FadeToken
	for _, entry in ipairs(UI.Fade) do
		entry.Group.GroupTransparency = 1
		task.delay(entry.Delay, function()
			if token == UI.FadeToken and Menu.IsOpen then
				Tween(entry.Group, UI.FadeInfo, { GroupTransparency = 0 })
			end
		end)
	end
end

function UI.FadeOut()
	UI.FadeToken += 1
	for _, entry in ipairs(UI.Fade) do
		Tween(entry.Group, UI.CloseInfo, { GroupTransparency = 1 })
	end
end

function Menu.Open()
	if Menu.IsOpen then
		return
	end
	Menu.IsOpen = true
	Watermark.Suppress(true)
	Window.Visible = true
	Content.Position = UDim2.new(0.5, 0, 0.5, 30)
	UI.Pop.Scale = 0.92
	MenuBlur.Enabled = true
	Tween(Dim, UI.OpenInfo, { BackgroundTransparency = 0.38 })
	Tween(MenuBlur, UI.OpenInfo, { Size = 20 })
	Tween(Content, UI.OpenInfo, { Position = UDim2.new(0.5, 0, 0.5, 0) })
	Tween(UI.Pop, UI.OpenInfo, { Scale = 1 })
	UI.FadeIn()
end

function Menu.Close()
	if not Menu.IsOpen then
		return
	end
	Menu.IsOpen = false
	Watermark.Suppress(false)
	Menu.CloseSettings()
	ClosePopup()
	for _, state in pairs(UI.Modals) do
		state.Set(false)
	end
	UI.FadeOut()
	local tw = Tween(Dim, UI.CloseInfo, { BackgroundTransparency = 1 })
	Tween(MenuBlur, UI.CloseInfo, { Size = 0 })
	Tween(Content, UI.CloseInfo, { Position = UDim2.new(0.5, 0, 0.5, 20) })
	Tween(UI.Pop, UI.CloseInfo, { Scale = 0.94 })
	tw.Completed:Connect(function()
		if not Menu.IsOpen then
			Window.Visible = false
			MenuBlur.Enabled = false
		end
	end)
end

function Menu.Toggle()
	if Menu.Calibrating then
		return
	end
	if Menu.Locked then
		Notify.Info(T("Подождите, скрипт ещё загружается."), T("Загрузка"), 3)
		return
	end
	if os.clock() - UI.LastToggle < 0.3 then
		return -- защита от двойного срабатывания
	end
	UI.LastToggle = os.clock()
	if Menu.IsOpen then
		Menu.Close()
	else
		Menu.Open()
	end
end


-- Кнопку открытия заменяет ватермарка
Watermark.OnClick = Menu.Toggle


-- ============================================================================
-- 11. ЗАПУСК: ПРЕДУПРЕЖДЕНИЕ -> ОТСЧЁТ -> ИНТРО -> ЗАГРУЗКА -> ГОТОВО
-- ============================================================================
local Boot = {}
local BootGui

local function BootGuiGet()
	if not BootGui or not BootGui.Parent then
		BootGui = Create("ScreenGui", {
			Name = "NNProject_Boot", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3000,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = PlayerGui,
		})
		Root:Give(BootGui)
	end
	return BootGui
end

local function BootScale(vx, vy, w, h)
	local cam = GetCamera()
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(vp.X / (w + 40), vp.Y / (h + 40)), 0.5, 1.2) * (IsMobile and 0.8 or 1)
end

-- ---------------------------------------------------------------- интро: "Добро пожаловать в..." -> NN -> Project
function Boot.Intro()
	local gui = BootGuiGet()
	local dim = Create("Frame", {
		Name = "IntroDim", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1), Active = true, Parent = gui,
	})
	local scaleFrame = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1, Parent = dim,
	}, { Create("UIScale", { Scale = BootScale(0, 0, 420, 300) }) })

	local welcome = Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(500, 40),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 28, TextColor3 = THEME.Text, TextTransparency = 1,
		Text = T("Добро пожаловать в..."), Parent = scaleFrame,
	})

	-- Буква N из трёх полос (две стойки + диагональ); контейнер обрезает концы диагонали ровно по высоте
	local NW, NH, NS_W = 76, 100, 16
	local function buildN(positionX)
		local n = Create("CanvasGroup", {
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(positionX, 0), Size = UDim2.fromOffset(NW, NH),
			BackgroundTransparency = 1, GroupTransparency = 1, Parent = scaleFrame,
		})
		local function bar(x, y, w, h, rot)
			return Create("Frame", {
				AnchorPoint = rot and Vector2.new(0.5, 0.5) or Vector2.new(0, 0), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
				Rotation = rot or 0, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = n,
			}, {
				Create("UIGradient", {
					Rotation = 90,
					Color = ColorSequence.new(Color3.fromRGB(205, 185, 255), Color3.fromRGB(125, 85, 220)),
				}),
			})
		end
		bar(0, 0, NS_W, NH)
		bar(NW - NS_W, 0, NS_W, NH)
		local length = math.sqrt((NW - NS_W) ^ 2 + NH ^ 2) + 8
		bar(NW / 2, NH / 2, NS_W, length, -math.deg(math.atan2(NW - NS_W, NH)))
		return n
	end

	local finalGap = NW - NS_W              -- вторая N встаёт так, что её левая стойка совпадает с правой стойкой первой
	local totalW = finalGap + NW
	local x1 = -totalW / 2
	local n1 = buildN(x1 - 380)
	local n2 = buildN(x1 + finalGap + 380)

	local project = Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 62), Size = UDim2.fromOffset(400, 34),
		BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 26, TextColor3 = THEME.Text, TextTransparency = 1,
		Text = "P R O J E C T", Parent = scaleFrame,
	})
	local pulse = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1, BorderSizePixel = 0, Parent = scaleFrame,
	}, { Corner(UDim.new(1, 0)) })
	local pulseStroke = Create("UIStroke", { Color = Color3.fromRGB(205, 185, 255), Thickness = 3, Transparency = 1, Parent = pulse })

	local fadeInfo = TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(dim, TI.Slow, { BackgroundTransparency = 0.35 })
	task.wait(0.4)
	Tween(welcome, fadeInfo, { TextTransparency = 0 })
	task.wait(2.0)

	-- Текст поднимается, из-за краёв экрана выезжают две N
	Tween(welcome, TI.Slow, { Position = UDim2.fromOffset(0, -118) })
	Sfx.PlayTimed("Intro", 0.8, 3, 0.7, 0.8)
	local slide = TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	Tween(n1, slide, { Position = UDim2.fromOffset(x1, 0), GroupTransparency = 0 })
	Tween(n2, slide, { Position = UDim2.fromOffset(x1 + finalGap, 0), GroupTransparency = 0 })
	task.wait(1.15)

	-- Слияние: вспышка-кольцо
	Tween(pulse, TweenInfo.new(0.8, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(340, 340) })
	pulseStroke.Transparency = 0.1
	Tween(pulseStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	task.wait(0.35)

	-- NN поднимаются на несколько пикселей, на месте нижних пикселей появляется "Project"
	Tween(n1, TI.Slow, { Position = UDim2.fromOffset(x1, -26) })
	Tween(n2, TI.Slow, { Position = UDim2.fromOffset(x1 + finalGap, -26) })
	task.wait(0.3)
	project.Position = UDim2.fromOffset(0, 70)
	Tween(project, TI.Slow, { TextTransparency = 0, Position = UDim2.fromOffset(0, 62) })
	task.wait(0.6)

	task.wait(CONFIG.IntroHold) -- интро стоит неподвижно

	-- ---- загрузка: NN и Project снова поднимаются, появляются полоса и статусы
	Tween(welcome, TI.Slow, { Position = UDim2.fromOffset(0, -156) })
	Tween(n1, TI.Slow, { Position = UDim2.fromOffset(x1, -52) })
	Tween(n2, TI.Slow, { Position = UDim2.fromOffset(x1 + finalGap, -52) })
	Tween(project, TI.Slow, { Position = UDim2.fromOffset(0, 40) })

	local status = Create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 86), Size = UDim2.fromOffset(480, 22),
		BackgroundTransparency = 1, Font = Enum.Font.GothamMedium, TextSize = 15, TextColor3 = THEME.Text,
		TextTransparency = 1, Text = "", Parent = scaleFrame,
	})
	local track = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(0, 114), Size = UDim2.fromOffset(300, 6),
		BackgroundColor3 = Color3.fromRGB(70, 60, 86), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = scaleFrame,
	}, { Corner(UDim.new(1, 0)) })
	local fill = Create("Frame", {
		Size = UDim2.fromScale(0, 1), BackgroundColor3 = THEME.AccentSoft, BackgroundTransparency = 1, BorderSizePixel = 0, Parent = track,
	}, { Corner(UDim.new(1, 0)) })
	task.wait(0.5)
	Tween(status, TI.Medium, { TextTransparency = 0 })
	Tween(track, TI.Medium, { BackgroundTransparency = 0.3 })
	Tween(fill, TI.Medium, { BackgroundTransparency = 0 })

	-- настоящая предзагрузка ассетов идёт параллельно этапу 5.2
	local finished = false
	local ids = {}
	for _, id in pairs(SOUND_IDS) do
		ids[#ids + 1] = tostring(id)
	end
	for _, list in ipairs({ DEATH_SOUNDS, HIT_SOUNDS }) do
		for _, s in ipairs(list) do
			ids[#ids + 1] = tostring(s.Id)
		end
	end
	ids[#ids + 1] = "101685860155742"

	-- 5.1: проверка среды клиента (4 с, полоса стоит на месте)
	status.Text = T("Проверка среды клиента")
	local function glide(target, seconds) -- плавное заполнение до target
		local tw = Tween(fill, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(target, 1) })
		tw.Completed:Wait()
	end
	glide(0.08, 0.9)
	task.wait(0.8) -- остановка
	glide(0.15, 0.8)
	task.wait(1.5) -- остановка (итого 4 с)

	-- 5.2: загрузка ассетов и звуков (8 с): код меняется каждые 37 мс
	task.spawn(function()
		local assets = { CONFIG.DeathParticleTexture }
		for _, id in ipairs(ids) do
			assets[#assets + 1] = "rbxassetid://" .. id
		end
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
		finished = true
	end)
	local prefix = T("Загрузка ассетов и звуков: ")
	Tween(fill, TweenInfo.new(8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(0.6, 1) }) -- без остановок
	local phaseStart = os.clock()
	while os.clock() - phaseStart < 8 do
		local code = (math.random() < 0.5) and ids[math.random(#ids)]
			or string.format("%06X%06X", math.random(0, 0xFFFFFF), math.random(0, 0xFFFFFF))
		status.Text = prefix .. code
		task.wait(0.037)
	end

	-- 5.3: проверка целостности данных (3.2 с)
	status.Text = T("Проверяю цельность данных")
	glide(0.72, 1.0)
	task.wait(0.8) -- остановка
	glide(0.85, 0.8)
	task.wait(0.6) -- остановка (итого 3.2 с)

	-- 5.4: загрузка скрипта (случайно 8-15 с), полоса идёт неровно, но не откатывается назад
	status.Text = T("Успешно, загружаю скрипт")
	local duration = math.random(8, 15)
	local started = os.clock()
	local shown = 0.85
	while true do
		local dt = RunService.Heartbeat:Wait()
		local elapsed = os.clock() - started
		local k = math.clamp(elapsed / duration, 0, 1)
		local eased = k * k * (3 - 2 * k)
		-- плавное сглаживание каждый кадр: полоса не дёргается и не откатывается назад
		shown += ((0.85 + 0.15 * eased) - shown) * ExpAlpha(5, dt)
		fill.Size = UDim2.fromScale(shown, 1)
		if elapsed >= duration and (finished or elapsed >= duration + 6) then
			break
		end
	end
	Tween(fill, TI.Fast, { Size = UDim2.fromScale(1, 1) })
	task.wait(0.4)

	local fadeOut = TweenInfo.new(1.0, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Tween(welcome, fadeOut, { TextTransparency = 1 })
	Tween(n1, fadeOut, { GroupTransparency = 1 })
	Tween(n2, fadeOut, { GroupTransparency = 1 })
	Tween(project, fadeOut, { TextTransparency = 1 })
	Tween(status, fadeOut, { TextTransparency = 1 })
	Tween(track, fadeOut, { BackgroundTransparency = 1 })
	Tween(fill, fadeOut, { BackgroundTransparency = 1 })
	local out = Tween(dim, fadeOut, { BackgroundTransparency = 1 })
	out.Completed:Wait()
	dim:Destroy()
end

-- ---------------------------------------------------------------- уведомление "Подождите / Загрузка" (случайно 10-20 с)
function Boot.Load()
	local handle = Notify.Loading(
		T("Подождите"),
		T("Загрузка"),
		T("Загружаем скрипт, это займет от 10 до 20 секунд. Проявите терпение пожалуйста.")
	)
	local assets = { CONFIG.DeathParticleTexture }
	for _, id in pairs(SOUND_IDS) do
		assets[#assets + 1] = "rbxassetid://" .. tostring(id)
	end
	for _, list in ipairs({ DEATH_SOUNDS, HIT_SOUNDS }) do
		for _, s in ipairs(list) do
			assets[#assets + 1] = "rbxassetid://" .. tostring(s.Id)
		end
	end
	assets[#assets + 1] = "rbxassetid://101685860155742"
	local finished = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)
		finished = true
	end)
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end

	-- время загрузки выбирается случайно после окончания интро
	local duration = math.random(CONFIG.MinLoadTime, CONFIG.MaxLoadTime)
	local start = os.clock()
	local shown = 0
	while true do
		local elapsed = os.clock() - start
		-- прогресс идёт рывками, как у настоящей загрузки, но никогда не откатывается назад
		local target = math.clamp(elapsed / duration, 0, 1) * (finished and 1 or 0.95)
		shown = math.max(shown, target - math.random() * 0.04)
		handle.SetProgress(shown)
		if elapsed >= duration and (finished or elapsed >= duration + 6) then
			break
		end
		task.wait(0.15 + math.random() * 0.25)
	end
	handle.SetProgress(1)
	task.wait(0.3)
	handle.Dismiss()
end

-- ---------------------------------------------------------------- финал запуска
function Boot.Ready()
	for _, id in ipairs({ "WmFps", "WmPing", "WmNick", "WmTariff", "Sounds", "Notifications" }) do
		SetFeature(id, true, true)
	end
	Watermark.SetVisible(true)
	Menu.Locked = false
	Menu.RefreshRows()
	-- проверка первого лица каждый кадр, сразу после камеры: косметика не успевает мелькнуть
	RunService:BindToRenderStep("NNProject_Cosmetics", Enum.RenderPriority.Camera.Value + 6, function()
		Cosmetics.Update(IsFirstPerson())
	end)
	Root:Give(function()
		pcall(function()
			RunService:UnbindFromRenderStep("NNProject_Cosmetics")
		end)
	end)
	Notify.Info(T("Скрипт загружен. Меню открывается кликом по ватермарке или клавишей RightShift."), T("Готово"))
	if CONFIG.OpenMenuOnStart then
		Menu.Open()
	end
end

-- ============================================================================
-- 12. ВВОД, ВЫГРУЗКА, API
-- ============================================================================
Root:Give(UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	for _, key in ipairs(CONFIG.ToggleKeys) do
		if input.KeyCode == key then
			Menu.Toggle()
			return
		end
	end
end))

local unloading = false

--- graceful = true: показывает прощание "Отключение..." со звуком распада, затем выгружает скрипт
Unload = function(graceful)
	if graceful then
		if unloading then
			return
		end
		unloading = true
		Menu.Locked = true
		Menu.Close()
		Watermark.SetVisible(false)
		Notify.Enabled = false -- новых уведомлений больше нет
		for i = #activeNotifications, 1, -1 do
			activeNotifications[i].Dismiss()
		end
		task.wait(0.4)
		Sfx.PlayTimed("Disintegrate", 0.9, 2.0, 0.05, 0.4)
		local farewell = Notify.Loading(T("Отключение..."), T("Подождите"), T("До следующего запуска!"), true)
		for i = 1, 12 do
			farewell.SetProgress(i / 12)
			task.wait(0.2)
		end
		farewell.Dismiss()
		task.wait(0.5)
	end
	for id, feature in pairs(Features) do
		if feature.Enabled and Modules[id] then
			pcall(Modules[id].Disable)
		end
	end
	pcall(Modules.ScreenShake.Stop)
	pcall(Modules.Atmosphere.Destroy)
	pcall(Modules.Fov.Disable)
	pcall(Target.Destroy)
	pcall(Env.Destroy)
	pcall(TimeCtl.Destroy)
	Root:Clean()
	pcall(function()
		Palette.Changed:Destroy()
	end)
	if ScreenGui then
		ScreenGui:Destroy()
	end
	if FxFolder then
		FxFolder:Destroy()
	end
	if _G.NNProject and _G.NNProject.Unload == Unload then
		_G.NNProject = nil
	end
end

_G.NNProject = {
	Version = CONFIG.Version,
	Notify = Notify,
	Menu = Menu,
	SetFeature = SetFeature,
	Shake = function(intensity, duration, options)
		return Modules.ScreenShake.Shake(intensity, duration, options)
	end,
	HitBurst = function(position, normal, scale)
		return Modules.HitFX.Burst(position, normal, scale)
	end,
	Unload = Unload,
}

-- ============================================================================
-- 13. СТАРТ
-- ============================================================================
Skin.Apply(Settings.UiSkin, true)
Menu.SelectTab(1, true)

task.spawn(function()
	if CONFIG.ShowWarning then
		task.wait(CONFIG.WarningCountdown) -- тихая пауза, без плавающего сообщения
	end
	if CONFIG.ShowIntro then
		Boot.Intro()
	end
	Boot.Ready()
end)
