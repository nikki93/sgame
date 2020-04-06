local sqlite3 = require 'lsqlite3'
local db = sqlite3.open_memory()


local function check(...)
    local code = db:errcode()
    if code ~= 0 then
        error('db error ' .. code .. ': ' .. db:errmsg(), 3)
    end
    return ...
end

local function prepare(...)
    return check(db:prepare(...))
end

local function run(s)
    while s:step() == sqlite3.ROW do
    end
    s:reset()
end

local function exec(...)
    check(db:exec(...))
end

local function execBind(sql, ...)
    local s = check(db:prepare(sql))
    check(s:bind_values(...))
    run(s)
end


exec([[
    pragma foreign_keys;

    create table object (
        id integer primary key,
        name
    );

    create table position (
        id, x, y,

        foreign key (id) references object(id)
    );

    create table circle (
        id, radius,

        foreign key (id) references object(id)
    );
]])


function love.load()
    local W, H = love.graphics.getDimensions()
    for i = 1, 20 do
        exec([[
            insert into object (name) values ("test");
        ]])
        local id = db:last_insert_rowid()
        execBind([[
            insert into position (id, x, y) values (?, ?, ?);
        ]], id, W * math.random(), H * math.random())
        execBind([[
            insert into circle (id, radius) values (?, 20);
        ]], id)
    end
end

local drawS = prepare([[
    select position.x, position.y, circle.radius
        from position, circle
        where position.id = circle.id;
]])
function love.draw()
    for x, y, radius in drawS:urows() do
        love.graphics.circle('fill', x, y, radius)
    end
    drawS:reset()
end


local ui = castle.ui

function castle.uiupdate()
    do return end
end
