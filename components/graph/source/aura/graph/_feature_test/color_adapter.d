module aura.graph._feature_test.test_graph;

debug (featureTest) {
    import aura.graph;
    import std.algorithm;
    import std.array;
    import std.format;
    
    class GraphTestModel : GraphModelInterface {
	   mixin GraphModelImplementation;
       mixin GraphModelId!string;

        string name;
        
        this() {
        }
    }
    class TestColor : GraphTestModel {
        enum Type {
            primary,
            secondary,
            tertiary
        }
        
        @byName Type type;
        ubyte red, green, blue;
        
        this() {
            super();
        }
        
        this(string color, ubyte r, ubyte g, ubyte b, Type type = Type.primary) {
            this.type = type;
            this.id = format("%02X%02X%02X", r, g, b);

            name = color;

            red = r;
            green = g;
            blue = b;
        }
    }
    
    class TestColorGroup : GraphTestModel {
    }
    
    class TestColorAdapter : GraphAdapter!(TestColor, TestColorGroup) {
        this() {
            initColor("red", 255, 0, 0, TestColor.Type.primary);    
            initColor("green", 0, 255, 0, TestColor.Type.primary);    
            initColor("blue", 0, 0, 255, TestColor.Type.primary);    
            initColor("magenta", 255, 0, 255, TestColor.Type.secondary);    
            initColor("yellow", 255, 255, 0, TestColor.Type.secondary);    
            initColor("cyan", 0, 255, 255, TestColor.Type.secondary);    
        }
        
        override GraphModelInterface[] graphFind(string graphType, string key, GraphValue value, uint limit = 0) {
            switch (graphType) {
                case "TestColor":
                    return array(findColor(key, value, limit).map!((c) => cast(GraphModelInterface)c));
                case "TestColorGrpi[":
                    return array(findColorGroup(key, value, limit).map!((c) => cast(GraphModelInterface)c));
                default:
                    return GraphModelInterface[].init;
            }
        }
        
        TestColor[] findColor(string key, GraphValue value, uint limit = 0) {
            switch (key) {
                case "id":
                    return array(_colors.filter!((c) => value == c.id));
                case "name":
                    return array(_colors.filter!((c) => value == c.name));
                case "type":
                    return array(_colors.filter!((c) => value == c.type));
                default: 
                    return TestColor[].init;
            }
        }
        
        TestColorGroup[] findColorGroup(string key, GraphValue value, uint limit = 0) {
            return TestColorGroup[].init;
        }
        
        private:
        
        void initColor(string name, ubyte r, ubyte g, ubyte b, TestColor.Type type = TestColor.Type.primary) {
            _colors ~= new TestColor(name, r, g, b, type);
        }
        TestColor[] _colors;        
        TestColorGroup[] _groups;        
    }
    
    class TestGraph : Graph {
        this() {
            _colorAdapter = new TestColorAdapter;
            
            defaultAdapter = _colorAdapter;
        }
        private:
        
        TestColorAdapter _colorAdapter;
    }
    
    import feature_test; 
    unittest {
        feature("Basic graph storage", (f) {
                    f.scenario("Should be able to inject a color into the graph", {
                            auto graph = new TestGraph;
                            auto blue = new TestColor("blue", 0, 0, 255);
                            graph.inject(blue);
                            graph.length.shouldEqual(1);
                            graph.inject(blue);
                            graph.length.shouldEqual(1);
                        });
                    f.scenario("Find a colour by type through the adapter", {
                        auto graph = new TestGraph;

                        auto results = graph.findMany!(TestColor, "type")(TestColor.Type.primary);
                        results.length.shouldEqual(3);

                        results = graph.findMany!(TestColor, "id")("FF0000");
                        results.length.shouldEqual(1);
                        results[0].name.shouldEqual("red");
                    });
                }); 
    }
}