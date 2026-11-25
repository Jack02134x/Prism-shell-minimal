.pragma library

function scoreWord(word, title, details) {
    if (title === word)
        return 0;
    if (title.startsWith(word))
        return 1;
    if (title.includes(word))
        return 2;
    if (details.includes(word))
        return 3;

    let cursor = 0;
    for (const character of word) {
        const index = title.indexOf(character, cursor);
        if (index < 0)
            return Infinity;
        cursor = index + 1;
    }
    return 4;
}

function rank(entries, query) {
    const trimmed = query.trim().toLowerCase();
    if (!trimmed)
        return entries;

    const words = trimmed.split(/\s+/);
    return entries.map(entry => {
        const title = (entry.searchTitle ?? entry.title).toLowerCase();
        const details = (entry.detail + " " + (entry.keywords ?? "")).toLowerCase();
        const score = title === trimmed ? -1 : words.reduce((total, word) => total + scoreWord(word, title, details), 0);
        return { entry, score };
    }).filter(match => Number.isFinite(match.score))
        .sort((left, right) => left.score - right.score)
        .map(match => match.entry);
}
