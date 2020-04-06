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
    create table color (
        id references object(id) on delete cascade,
        r, g, b
    );
]], [[
    create table circle (
        id references object(id) on delete cascade,
        radius
    );
]]}))


function love.load()
    local W, H = love.graphics.getDimensions()
    for i = 1, 200 do
        run(prepare([[
            insert into object (name) values ("test");
        ]]))
        local id = db:last_insert_rowid()
        run(prepare({[[
            insert into position (id, x, y) values ($id, $x, $y);
        ]], [[
            insert into velocity (id, vx, vy) values ($id, 0, 0);
        ]], [[
            insert into color (id, r, g, b) values ($id, $r, $g, $b);
        ]], [[
            insert into circle (id, radius) values ($id, $radius);
        ]]}), {
            id = id,
            x = W * math.random(),
            y = H * math.random(),
            r = math.random(),
            g = math.random(),
            b = math.random(),
            radius = math.random(20, 60),
        })
    end
end


local drawCircleS = prepare([[
    select position.x, position.y, color.r, color.g, color.b, circle.radius
        from position, color, circle
        where position.id = color.id and position.id = circle.id;
]])
function love.draw()
    for x, y, r, g, b, radius in drawCircleS:urows() do
        love.graphics.setColor(r, g, b)
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
            vy = -abs(vy)
        where
            exists (
                select *
                    from position, circle
                    where
                        position.id = velocity.id and
                        position.id = circle.id and
                        position.y + circle.radius > $H
            )
]]})
function love.update(dt)
    local W, H = love.graphics.getDimensions()
    run(updateS, {
        dt = dt,
        W = W,
        H = H,
    })
end
