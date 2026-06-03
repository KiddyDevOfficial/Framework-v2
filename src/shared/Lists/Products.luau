--!nocheck
--[=[
    @module Products
    @description A list of products that can be purchased in the game.
]=]

local RunService = game:GetService("RunService")
local IS_SERVER = RunService:IsServer()

export type Products = {
    GetProduct: (name: string) -> Product?,
    GetProductByTag: (tag: string) -> Product?,
    GetProductById: (id: number) -> Product?,
    GetAllProducts: () -> { Product },
    Products: { Product },
}

export type Product = {
    id: number,
    name: string,
    tag: string?,
    handler: (player: Player, receipt: ReceiptInfo) -> boolean,
}

local Products: Products = {}
Products.Products = {
    --[=[
        {
        id = 112213,
        name = "Test Product",
        tag = "product_1",
        handler = function(player, receipt)
            if not IS_SERVER then
                return false
            end
            return true
        end,
    },
    ]=]-- Example product
}

function Products.GetProduct(name: string): Product?
    for _, product in Products.Products do
        if product.name == name then
            return product
        end
    end
    return nil
end

function Products.GetProductByTag(tag: string): Product?
    for _, product in Products.Products do
        if product.tag == tag then
            return product
        end
    end
    return nil
end

function Products.GetProductById(id: number): Product?
    for _, product in Products.Products do
        if product.id == id then
            return product
        end
    end
    return nil
end

function Products.GetAllProducts(): { Product }
    return Products.Products
end

return Products :: Products