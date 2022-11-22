


import std.stdio;

class RangeDetector(T)
{

    unittest
    {
        RangeDetector!(real) rd = new RangeDetector!(real);
        rd = 1;
        rd = 2;
        rd = -1;
        rd = -4;
        assert(rd.minValue == -4);
        assert(rd.maxValue == 2);

        RangeDetector!(real) rd2 = new RangeDetector!(real);
        rd2 = rd;
        assert(rd2.minValue == -4);
        assert(rd2.maxValue == 2);

        //writefln(rd);
    }

    void opAssign(T newValue)
    {
        if(newValue > maxValue) maxValue = newValue;
        if(newValue < minValue) minValue = newValue;
    }

    char[] toString()
    {
        return "[" ~ std.string.toString(minValue) ~ " - " ~ std.string.toString(maxValue) ~ "]";
    }

    T getMin() { return minValue; }
    T getMax() { return maxValue; }

    void reset()
    {
        minValue = real.max;
        maxValue = - real.max;
    }

    private:

    T minValue = T.max;
    T maxValue = -T.max;

}

/*
class RealRangeDetector
{

    unittest
    {
        RealRangeDetector rd = new RealRangeDetector;
        rd = 1;
        rd = 2;
        rd = -1;
        rd = -4;
        assert(rd.minValue == -4);
        assert(rd.maxValue == 2);

        RealRangeDetector rd2 = new RealRangeDetector;
        rd2 = rd;
        assert(rd2.minValue == -4);
        assert(rd2.maxValue == 2);

        //writefln(rd);
    }

    void opAssign(real newValue)
    {
        if(newValue > maxValue) maxValue = newValue;
        if(newValue < minValue) minValue = newValue;
    }

    char[] toString()
    {
        return "[" ~ std.string.toString(minValue) ~ " - " ~ std.string.toString(maxValue) ~ "]";
    }

    real getMin() { return minValue; }
    real getMax() { return maxValue; }

    void reset()
    {
        minValue = real.max;
        maxValue = - real.max;
    }

    private:

    real minValue = real.max;
    real maxValue = - real.max;

}

*/

// istanziamo! senno' mi puo' dare problemi in link...
typedef RangeDetector!(real) RealRangeDetector;

