-- 建立一個空的 Table
local PartFactory = {}

-- 將類別 __index 指向自己，這是實現「物件導向 (OOP)」的關鍵
-- 當你在實例上找不到某個方法時，Lua 會去這個 PartFactory(尋找PartFactory) 裡找
PartFactory.__index = PartFactory

--[[
    @method new
    這是建構函數 (Constructor)，用來實例化一個新的 Part 物件。
    @param position : Vector3 - 決定物件生成的 3D 座標位置
    @param config : table - 一個字典，讓你自定義要覆蓋的屬性（例如顏色、材質）
]]
function PartFactory.new(position: Vector3, config: { [string]: any })
	-- 		1. 建立一個空的表作為「實例 (Instance)」，並與類別藍圖綁定
		local self = setmetatable({}, PartFactory)

	-- 2. 核心物件生成：雖然是 Instance.new，但封裝在 self._instance 內部
	self._instance = Instance.new("Part")

	-- 3. 設定預設屬性 (Default Properties)
	-- 這能確保即便外部沒有傳入參數，物件也能正常運作，不會因為缺少關鍵數值而報錯
	local defaultProps = {
		Size = Vector3.new(4, 4, 4),
		Position = position,
		Anchored = true,      -- 預設固定在空中
		Parent = workspace    -- 預設放入遊戲空間 
	}

	-- 4. 字典合併 (Table Merge) 邏輯
	-- 如果用戶有傳入自定義的 config，則遍歷它並用來替換掉 defaultProps 裡的預設值
	for prop, value in pairs(config or {}) do
		defaultProps[prop] = value
	end

	-- 5. 批次屬性注入
	-- 遍歷最終確定的屬性清單，一次性賦值給真正的 Roblox Part 實體
	-- 這種寫法比一行一行寫 self._instance.Color = ... 更具有擴展性
	for prop, value in pairs(defaultProps) do
		self._instance[prop] = value
	end

	-- 6. 回傳這個封裝好的物件，讓外部可以繼續操作它
	return self
end

-- 使用方法：
-- 調用 Factory 建立一個位於 (0, 10, 0) 的紅色霓虹方塊
local myPart = PartFactory.new(Vector3.new(0, 10, 0), {
	Color = Color3.fromRGB(255, 0, 0),  -- 覆蓋預設顏色
	Material = Enum.Material.Neon       -- 覆蓋預設材質
})