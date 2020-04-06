local sqlite3 = require 'lsqlite3'
local db = sqlite3.open_memory()


local function check(...)
    local code = db:errcode()
    if code ~= 0 then
        error('db error ' .. code .. ': ' .. db:errmsg(), 3)
    end
    return ...
end

local function prepare(sql)
    if type(sql) == 'table' then
        local r = {}
        for _, each in ipairs(sql) do
            table.insert(r, prepare(each))
        end
        return r
    end
    return (check(db:prepare(sql)))
end

local function run(s, ...)
    if type(s) == 'table' then
        for _, each in ipairs(s) do
            run(each, ...)
        end
        return
    end
    if select('#', ...) > 0 then
        if type(select(1, ...)) == 'table' then
            s:bind_names(...)
        else
            s:bind_values(...)
        end
    end
    while s:step() == sqlite3.ROW do
    end
    s:reset()
end


run(prepare({[[
    pragma foreign_keys = on;
]], [[
    create table object (
        id integer primary key,
        name
    );
]], [[
    create table position (
        id references object(id) on delete cascade,
        x, y
    );
]], [[
    create table velocity (
        id references object(id) on delete cascade,
        vx, vy
    );
]], [[
    create table circle (
        id references object(id) on delete cascade,
        radius
    );
]]}))


function love.load()
    local W, H = love.graphics.getDimensions()
    for i = 1, 20 do
        run(prepare([[
            insert into object (name) values ("test");
        ]]))
        local id = db:last_insert_rowid()
        run(prepare({[[
            insert into position (id, x, y) values ($id, $x, $y);
        ]], [[
            insert into velocity (id, vx, vy) values ($id, 0, 0);
        ]], [[
            insert into circle (id, radius) values ($id, 20);
        ]]}), { id = id, x = W * math.random(), y = H * math.random() })
    end
end


local drawCircleS = prepare([[
    select position.x, position.y, circle.radius
        from position, circle
        where position.id = circle.id;
]])
function love.draw()
    for x, y, radius in drawCircleS:urows() do
        love.graphics.circle('fill', x, y, radius)
    end
    drawCircleS:reset()
end


local updateS = prepare({[[
    update velocity
        set
            vy = vy + 32 * 9.8 * $dt;
]], [[
    update position
        set
            (x, y) = (
                select position.x + velocity.vx * $dt, position.y + velocity.vy * $dt
                    from velocity
                    where position.id = velocity.id
            )
        where
            exists (
                select *
                    from position, velocity
                    where position.id = velocity.id
            );
]], [[
    update velocity
        set
            vy = -vy
        where
            exists (
                select *
                    from position
                    where position.id = velocity.id and position.y > $H
            )
]], [[
    update position
        set y = $H
        where y > $H;
]]})
function love.update(dt)
    local W, H = love.graphics.getDimensions()
    run(updateS, {
        dt = dt,
        W = W,
        H = H,
    })
end
