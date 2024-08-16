using MoonSharp.Interpreter;

const string PATH = "../dist/main.lua";

const string TEST_SCRIPT_1 = @"
    local s = ""Regardless of the century, plane, or species, developing artificers never fail to invent the ornithopter.""
    local t = s:sub(1, 60)

    for word in t:gmatch(""([^//]+)"") do
        local trimmed = word:gsub('^%s*(.-)%s*$', '%1')
        table.insert(nameParts, trimmed)
    end
";


double ExecuteScript()
{
	using var reader = new StreamReader(PATH);
    string script = reader.ReadToEnd();

	DynValue res = Script.RunString(script);
	return res.Number;
}

ExecuteScript();
