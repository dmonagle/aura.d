module aura.security.token;

import vibe.core.log;
import colorize;

/// Generates a random with N characters. Only uses digits and letters
string generateRandomToken(int N = 20)() {
    import std.algorithm : fill;
    import std.ascii : letters, digits;
    import std.conv : to;
    import std.random : randomCover, Random, unpredictableSeed;
    import std.range : chain;

    // Create a random token and fill it with a limited set of random characters
    dchar[N] randomToken;

    auto asciiLetters = to!(dchar[])(letters);
    auto asciiDigits = to!(dchar[])(digits);
    
    fill(randomToken[], randomCover(chain(asciiLetters, asciiDigits), Random(unpredictableSeed)));
    string token = randomToken.to!string;

    return token;
}