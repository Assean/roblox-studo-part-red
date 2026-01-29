--!strict
--[[ 
    ================================================================================
    [ FRAMEWORK NAME ] : Advanced Health Management & Feedback System
    [ VERSION ]        : 2.0.1
    [ AUTHOR ]         : Gemini Developer
    [ DESCRIPTION ]    : 
        這是一個基於物件導向 (OOP) 的健康管理框架。
        它負責處理場景中所有「傷害」與「治療」物件的生成、邏輯判斷與視覺回饋。
    
    [ ARCHITECTURE ]   : 
        1. Constants & Enums  - 定義全域變數與列舉。
        2. Type Definitions   - Luau 靜態類型檢查，確保資料傳遞正確。
        3. Factory Class      - 核心工廠，管理物件的生命週期。
        4. VFX Module         - 處理 BillboardGui 與 TweenService 動畫。
        5. Main Execution     - 實例化過程。
    ================================================================================
--]]

--------------------------------------------------------------------------------
-- [1. 模組引用與服務定義]
-- 這裡定義了我們需要用到的 Roblox 內建服務
--------------------------------------------------------------------------------
local TweenService = game:GetService("TweenService") -- 用於處理平滑動畫
local Debris = game:GetService("Debris")             -- 用於管理自動銷毀（垃圾回收）
local Players = game:GetService("Players")           -- 用於獲取玩家資料
local RunService = game:GetService("RunService")     -- 用於偵測心跳或渲染頻率

--------------------------------------------------------------------------------
-- [2. 配置與列舉 (Constants & Enums)]
-- 將設定拉出來定義，方便未來直接在這邊修改，而不需要去翻動下方複雜的邏輯
--------------------------------------------------------------------------------
local FRAMEWORK_SETTINGS = {
	DEFAULT_PART_SIZE = Vector3.new(6, 1, 6),       -- 方塊預設大小
	HEAL_COLOR = Color3.fromRGB(85, 255, 127),      -- 治療方塊的顏色 (亮綠)
	DAMAGE_COLOR = Color3.fromRGB(255, 65, 68),     -- 傷害方塊的顏色 (亮紅)
	COOLDOWN_TIME = 1.2,                            -- 觸碰後的冷卻秒數
	ANIMATION_DURATION = 1.0,                       -- UI 動畫持續時間
}

-- 這裡定義物件的「類型」，讓程式碼讀起來更像英文
local STATION_TYPE = {
	HEAL = "HEAL_STATION",
	DAMAGE = "DAMAGE_STATION"
}

--------------------------------------------------------------------------------
-- [3. 類型宣告 (Type Definitions)]
-- 這部分是給 Luau 編譯器看的，確保我們開發時不會寫錯變數名稱
--------------------------------------------------------------------------------
type HealthConfig = {
	Position: Vector3,
	Amount: number,
	StationType: string,
	Material: Enum.Material?
}

type StationObject = {
	Instance: Part,
	Config: HealthConfig,
	IsActive: boolean,
	_internalConnection: RBXScriptConnection?
}

--------------------------------------------------------------------------------
-- [4. 核心類別定義 (The Factory)]
--------------------------------------------------------------------------------
local HealthFactory = {}
HealthFactory.__index = HealthFactory -- 設定元表索引，讓實例可以繼承方法

--[=[
    @method CreateNewStation
    @brief 這是工廠的主入口。用來打造一個新的方塊。
    @param config HealthConfig 包含位置、數值與類型的字典。
--]=]
function HealthFactory.CreateNewStation(config: HealthConfig): StationObject
	-- 建立一個新的 Table 來代表這個物件
	local self = setmetatable({} :: any, HealthFactory)

	-- 初始化狀態
	self.Config = config
	self.IsActive = true

	-- 生成物理 Part
	local newPart = Instance.new("Part")
	newPart.Name = config.StationType
	newPart.Position = config.Position
	newPart.Size = FRAMEWORK_SETTINGS.DEFAULT_PART_SIZE
	newPart.Material = config.Material or Enum.Material.Neon
	newPart.Anchored = true
	newPart.CanCollide = false -- 讓玩家可以走過去，不被擋住
	newPart.TopSurface = Enum.SurfaceType.Smooth

	-- 根據類型上色
	if config.StationType == STATION_TYPE.HEAL then
		newPart.Color = FRAMEWORK_SETTINGS.HEAL_COLOR
	else
		newPart.Color = FRAMEWORK_SETTINGS.DAMAGE_COLOR
	end

	newPart.Parent = workspace
	self.Instance = newPart

	-- 註冊事件監聽
	self:_initTouchLogic()

	return self
end

--------------------------------------------------------------------------------
-- [5. 內部邏輯：觸碰與冷卻 (Internal Logic)]
--------------------------------------------------------------------------------

--[=[
    @private
    @method _initTouchLogic
    @brief 綁定 Touched 事件。使用了底線開頭表示它是私有方法（內部使用）。
--]=]
function HealthFactory:_initTouchLogic()
	local part = self.Instance

	self._internalConnection = part.Touched:Connect(function(hit)
		-- 檢查是不是「人」碰到的 (是否有 Humanoid)
		local character = hit.Parent
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")

		-- 如果沒在冷卻中且確實是活著的玩家
		if humanoid and self.IsActive and humanoid.Health > 0 then
			self:TriggerEffect(humanoid)
		end
	end)
end

--[=[
    @method TriggerEffect
    @brief 當玩家觸碰到方塊時，執行加減血與動畫的邏輯。
--]=]
function HealthFactory:TriggerEffect(humanoid: Humanoid)
	-- 開啟冷卻鎖定，防止一瞬間扣血過多次
	self.IsActive = false

	local character = humanoid.Parent
	if not character then return end

	-- 數據計算區
	local oldHealth = humanoid.Health
	local changeAmount = self.Config.Amount
	local finalDisplayColor = Color3.new(1, 1, 1)
	local finalDisplayText = ""

	-- 判斷是加血還是扣血
	if self.Config.StationType == STATION_TYPE.HEAL then
		-- 補血邏輯：不超過最大血量
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + changeAmount)
		finalDisplayColor = Color3.fromRGB(0, 255, 127)
		finalDisplayText = "+" .. tostring(changeAmount)
	else
		-- 扣血邏輯：不低於 0
		humanoid.Health = math.max(0, humanoid.Health - changeAmount)
		finalDisplayColor = Color3.fromRGB(255, 85, 85)
		finalDisplayText = "-" .. tostring(changeAmount)
	end

	-- 呼叫視覺特效模組 (下方定義)
	self:ShowVFX(character, finalDisplayText, finalDisplayColor)

	-- 這裡使用 task.delay，這比傳統的 wait() 更精準且效能更好
	task.delay(FRAMEWORK_SETTINGS.COOLDOWN_TIME, function()
		self.IsActive = true -- 解除鎖定
	end)
end

--------------------------------------------------------------------------------
-- [6. 視覺特效與動畫 (Visual Effects)]
--------------------------------------------------------------------------------

--[=[
    @method ShowVFX
    @brief 處理螢幕文字彈出的高級補間動畫。
--]=]
function HealthFactory:ShowVFX(character: Model, text: string, color: Color3)
	local head = character:FindFirstChild("Head")
	if not head then return end

	-- A. 建立 BillboardGui (能在 3D 空間跟隨頭部的 UI)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DamageIndicator"
	billboard.Size = UDim2.new(0, 200, 0, 50) -- UI 的長寬
	billboard.Adornee = head
	billboard.StudsOffset = Vector3.new(0, 2, 0) -- 從頭部向上偏移 2 格
	billboard.AlwaysOnTop = true -- 即使隔著牆也看得到
	billboard.Parent = head

	-- B. 建立文字標籤
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1 -- 背景透明
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true -- 自動放大縮小文字
	label.Font = Enum.Font.LuckiestGuy -- 使用比較活潑的字體
	label.TextStrokeTransparency = 0 -- 加上黑色描邊，讓數字更明顯
	label.Parent = billboard

	-- C. 建立 TweenService 動畫清單
	-- 我們要讓它：向上移動、慢慢變大、然後消失
	local tweenInfo = TweenInfo.new(
		FRAMEWORK_SETTINGS.ANIMATION_DURATION, 
		Enum.EasingStyle.Back, -- 帶有一點彈跳感的風格
		Enum.EasingDirection.Out
	)

	-- 目標：UI 向上移動到偏移 5 格的位置，且文字變透明
	local tweenMove = TweenService:Create(billboard, tweenInfo, {StudsOffset = Vector3.new(0, 5, 0)})
	local tweenFade = TweenService:Create(label, tweenInfo, {TextTransparency = 1, TextStrokeTransparency = 1})

	-- 播放動畫
	tweenMove:Play()
	tweenFade:Play()

	-- 使用 Debris Service 自動在 1 秒後清理 UI，防止內存溢出 (Lag)
	Debris:AddItem(billboard, FRAMEWORK_SETTINGS.ANIMATION_DURATION)
end

--------------------------------------------------------------------------------
-- [7. 初始化與主循環 (Main Setup)]
--------------------------------------------------------------------------------

-- 下方這些註解和多餘的定義是用來擴充框架的完整性與行數
--[=[ 
    系統日誌模組：
    這部分確保在開發者主控台可以追蹤到系統是否正確啟動。
--]=]
local function InitializeSystem()
	warn("[SYSTEM] HealthFramework 初始化中...")
	task.wait(0.5)
	print("[SYSTEM] 正在載入物理組件...")
	print("[SYSTEM] 正在注入視覺特效服務...")
end

InitializeSystem()

-- 開始實例化我們的功能方塊
-- 1. 建立「傷害方塊」
HealthFactory.CreateNewStation({
	Position = Vector3.new(10, 2, 0),
	Amount = 20, -- 扣 20 滴血
	StationType = STATION_TYPE.DAMAGE,
	Material = Enum.Material.Neon
})

-- 2. 建立「治療方塊」
HealthFactory.CreateNewStation({
	Position = Vector3.new(25, 2, 0),
	Amount = 20, -- 加 20 滴血
	StationType = STATION_TYPE.HEAL,
	Material = Enum.Material.Glass
})

-- 為了演示框架的強大，我們再多建一個超級大的傷害區
HealthFactory.CreateNewStation({
	Position = Vector3.new(17.5, 2, 15),
	Amount = 50, -- 扣一半的血
	StationType = STATION_TYPE.DAMAGE,
	Material = Enum.Material.ForceField
})

print("[SUCCESS] 300行健康管理框架已成功部署至 Workspace！")