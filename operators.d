
import std.math;
import std.random;
import std.string;
import std.stdio;
import std.stream;


import individual;

class Operator
{
    short arity;

    real eval(Node[] children, real[] params)
    {
        assert(children.length == arity);
        return real.nan;
    }

    abstract char[] toString(char[][]);

    abstract void save(File f);

    Operator clone()
    {
        char[] classToCreate = this.classinfo.name;
        Operator toReturn = OperatorsFactory.makeOperator(this.classinfo.name);
        assert( toReturn !is null, "cannot factory " ~ classToCreate);
        return toReturn;
    }

}


real minRange = -PI * 2;
real maxRange = PI * 2;


class Constant : Operator
{
    this()
    {
        arity = 0;

        value = minRange + ((maxRange - minRange) * (cast(float) rand() / uint.max));
    }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        return value;
    }

    char[] toString(char[][] childrenStrings)
    {
        assert(childrenStrings == null);
        return std.string.toString(value);
    }

    void applyDelta()
    {
        real delta = minRange + ((maxRange - minRange) * (cast(float) rand() / uint.max));
        delta *= 0.05;
        value += delta;
    }

    void save(File f)
    {
        f.writef("%f ", value);
    }

    Constant clone()
    {
        Constant toReturn = cast (Constant) Operator.clone;
        toReturn.value = value;
//        toReturn.minRange = minRange;
//        toReturn.maxRange = maxRange;

        return toReturn;
    }

    unittest
    {
        Constant c1 = new Constant;
        c1.value = 5.0;
        Constant c2 = c1.clone();
        assert(c2.value == 5.0);
        Constant c3 = new Constant;
        c2 = c3.clone();
        assert(c2.value == c3.value);
        assert(c2.arity== c3.arity);

    }

    real value;
}


class Variable : Operator
{
    this(uint idx)
    {
        arity = 0;
        index = idx;
    }

    // per la creazione via factory
    this()
    {
        this(-1);
    }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        return params[index];
    }

    char[] toString(char[][] childrenStrings)
    {
        return "X" ~ std.string.toString(index);
    }

    void save(File f)
    {
        f.writef("%s ", "X" ~ std.string.toString(index));
    }

    Variable clone()
    {
        Variable toReturn = cast (Variable) Operator.clone;
        toReturn.index = index;
//        toReturn.minRange = minRange;
//        toReturn.maxRange = maxRange;

        return toReturn;
    }

    unittest
    {
        Variable c1 = new Variable(1);
        c1.index = 5;
        Variable c2 = c1.clone();
        assert(c2.index == 5);
        Variable c3 = new Variable(2);
        c2 = c3.clone();
        assert(c2.index == c3.index);
        assert(c2.arity== c3.arity);
    }

    short index;
}


class Add : Operator
{
    this()
    {
        arity = 2;
    }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        real n2 = children[1].eval(params);
        if(isnan(n2))
            return real.nan;

        return  n1 + n2;
    }

    char[] toString(char[][] childrenStrings)
    {
        return "(" ~ childrenStrings[0] ~ " + " ~ childrenStrings[1] ~ ")";
    }

    void save(File f)
    {
        f.writef("Add ");
    }

    unittest
    {
        Add c1 = new Add;
        Add c2 = cast(Add) c1.clone;
        assert(c1.arity== c2.arity);
    }


}

class Sub : Operator
{
    this() { arity = 2; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        real n2 = children[1].eval(params);
        if(isnan(n2))
            return real.nan;

        return n1 - n2;
    }

    char[] toString(char[][] childrenStrings)
    {
        return "(" ~ childrenStrings[0] ~ " - " ~ childrenStrings[1] ~ ")";
    }

    void save(File f)
    {
        f.writef("Sub ");
    }

}

class Mult : Operator
{
    this() { arity = 2; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        real n2 = children[1].eval(params);
        if(isnan(n2))
            return real.nan;

        return n1 * n2;
    }

    char[] toString(char[][] childrenStrings)
    {
        return "(" ~ childrenStrings[0] ~ " * " ~ childrenStrings[1] ~ ")";
    }

    void save(File f)
    {
        f.writef("Mult ");
    }

}

class Div : Operator
{
    this() { arity = 2; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);

        real n2 = children[1].eval(params);
        if(isnan(n2) || n2 == 0)
            return real.nan;

        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return n1 / n2;

    }

    char[] toString(char[][] childrenStrings)
    {
        return "(" ~ childrenStrings[0] ~ " / " ~ childrenStrings[1] ~ ")";
    }

    void save(File f)
    {
        f.writef("Div ");
    }

}


class Pow : Operator
{
    this() { arity = 2; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        real n2 = children[1].eval(params);
        if(isnan(n2))
            return real.nan;

        return pow(n1, n2);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "pow(" ~ childrenStrings[0] ~ ", " ~ childrenStrings[1] ~ ")";
    }

    void save(File f)
    {
        f.writef("Pow ");
    }

}

class Sin : Operator
{
    this() { arity = 1; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return sin(n1);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "sin(" ~ childrenStrings[0] ~ ")";
    }

    void save(File f)
    {
        f.writef("Sin ");
    }

}

class Cos : Operator
{
    this() { arity = 1; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return cos(n1);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "cos(" ~ childrenStrings[0] ~ ")";
    }

    void save(File f)
    {
        f.writef("Cos ");
    }

}


class Exp : Operator
{
    this() { arity = 1; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return exp(n1);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "exp(" ~ childrenStrings[0] ~ ")";
    }

    void save(File f)
    {
        f.writef("Exp ");
    }

}

class Log : Operator
{
    this() { arity = 1; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return log(n1);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "log(" ~ childrenStrings[0] ~ ")";
    }

    void save(File f)
    {
        f.writef("Log ");
    }

}


class Abs : Operator
{
    this() { arity = 1; }

    real eval(Node[] children, real[] params)
    {
        //super.eval(children, params);
        real n1 = children[0].eval(params);
        if(isnan(n1))
            return real.nan;

        return abs(n1);
    }

    char[] toString(char[][] childrenStrings)
    {
        return "abs(" ~ childrenStrings[0] ~ ")";
    }

    void save(File f)
    {
        f.writef("Abs ");
    }

}


class OperatorsFactory
{
    Operator makeRandomOperator()
    {

        if(operatorsToUse.length == 0)
        {
            writefln("Please add some operators to use to this OperatorsFactory");
            throw new Error("zero size operators array");
        }

        char[] opToUse = operatorsToUse[rand() % length];

        Operator o = makeOperator(opToUse);
        return o;
    }

    Operator makeRandomTerminal()
    {
        // questo e' lievemente diverso
        if(rand() % 2)
            return new Constant;
        else
            return new Variable(rand() % nVariables);
    }

    this(uint nVars)
    {
        nVariables = nVars;
    }

    void addOperator(char[] op)
    {
        operatorsToUse ~= op;
    }

    static Operator makeOperator(char[] classname)
    {
        //version(Windows)
        //{
        //    Object o = factory(classname);
        //}
        //version(darwin)
        //{
            Operator o;
            switch(classname)
            {
                case "Abs":
                case "operators.Abs":
                    o = new Abs;
                    break;

                case "Add":
                case "operators.Add":
                    o = new Add;
                    break;

                case "Exp":
                case "operators.Exp":
                    o = new Exp;
                    break;

                case "Sub":
                case "operators.Sub":
                    o = new Sub;
                    break;

                case "Mult":
                case "operators.Mult":
                    o = new Mult;
                    break;

                case "Div":
                case "operators.Div":
                    o = new Div;
                    break;

                case "Cos":
                case "operators.Cos":
                    o = new Cos;
                    break;

                case "Log":
                case "operators.Log":
                    o = new Log;
                    break;

                case "Sin":
                case "operators.Sin":
                    o = new Sin;
                    break;

                case "Pow":
                case "operators.Pow":
                    o = new Pow;
                    break;

                case "Variable":
                case "operators.Variable":
                    o = new Variable;
                    break;

                case "Constant":
                case "operators.Constant":
                    o = new Constant;
                    break;

                default:
                    writefln("Error! Operator unknown: "~classname);
                    break;

            }
        //}

        if(o is null)
        {
            writefln("Operator unknown: " ~ classname);
        }
        return cast(Operator)o;
    }



    char[][] operatorsToUse;

    uint nVariables;

}
