-- =========================================================
-- ComboExplorer/core/CatalogAudit.lua - checks the built catalog against the
-- action ids the game actually produced. Pure.
-- =========================================================
--
-- WHY THIS IS WORTH A PROBE OF ITS OWN
--
-- The catalog is built from a data file generated against one AC/BCM pair on
-- one patch. Everything downstream is keyed on its action ids, so if those ids
-- have moved, every recorded edge is about a move nobody meant. The failure is
-- silent: an id that no longer exists simply never appears, and an id that now
-- means something else is recorded under the old name.
--
-- The check costs nothing. The read-only build already watches action ids go
-- past while the operator plays; comparing that stream against the catalog says
-- whether the two describe the same game.
--
-- It also does real work toward the canonical/variant question. The catalog
-- groups 617/618/619 and refuses to say which one an input produces. An id in
-- such a group that NEVER appears across a long session is evidence - not
-- proof, but the kind of evidence that makes a calibration sweep shorter.

local M = { name = "ComboExplorer.CatalogAudit" }

-- catalog        : as built by core/Catalog.lua
-- observed_ids   : { [action_id] = times_entered }, e.g. from ProbeA's histogram
function M.audit(catalog, observed_ids, opts)
    opts = opts or {}
    observed_ids = observed_ids or {}

    if type(catalog) ~= "table" or type(catalog.rows) ~= "table" then
        return nil, "not a catalog"
    end

    -- Every action id the catalog knows about, and whether it was seen.
    local known, known_count = {}, 0
    for _, row in ipairs(catalog.rows) do
        if known[row.action_id] == nil then
            known[row.action_id] = { action_id = row.action_id, seen = 0, rows = 0,
                                     standalone = false, categories = {} }
            known_count = known_count + 1
        end
        local k = known[row.action_id]
        k.rows = k.rows + 1
        if row.standalone then k.standalone = true end
        k.categories[row.category] = true
    end

    local seen_known, seen_total = 0, 0
    for id, n in pairs(observed_ids) do
        seen_total = seen_total + 1
        local k = known[id]
        if k then
            k.seen = n
            seen_known = seen_known + 1
        end
    end

    -- Ids the game produced that the catalog has never heard of. Expected in
    -- some number - the catalog's own _meta lists hundreds of unmapped ids -
    -- but a large or growing set is the signal that the data has drifted from
    -- the build.
    local unknown = {}
    for id, n in pairs(observed_ids) do
        if not known[id] then unknown[#unknown + 1] = { action_id = id, seen = n } end
    end
    table.sort(unknown, function(a, b)
        if a.seen ~= b.seen then return a.seen > b.seen end
        return a.action_id < b.action_id
    end)

    -- Catalogued ids that never appeared. Only meaningful for standalone rows:
    -- a follow-up or an assist-combo step is not expected to show up in free
    -- play, so counting it as missing would be noise.
    local unseen_standalone = {}
    for id, k in pairs(known) do
        if k.standalone and k.seen == 0 then
            unseen_standalone[#unseen_standalone + 1] = id
        end
    end
    table.sort(unseen_standalone)

    -- Group evidence: within an ambiguous notation group, which member ids the
    -- game has actually produced.
    local groups = {}
    for key, g in pairs(catalog.groups or {}) do
        if g.ambiguous then
            local seen_ids, unseen_ids = {}, {}
            for _, id in ipairs(g.action_ids) do
                if (observed_ids[id] or 0) > 0 then
                    seen_ids[#seen_ids + 1] = id
                else
                    unseen_ids[#unseen_ids + 1] = id
                end
            end
            groups[#groups + 1] = {
                display_group = key,
                notation = g.notation,
                input_method = g.input_method,
                action_ids = g.action_ids,
                seen = seen_ids,
                unseen = unseen_ids,
                canonical_status = g.canonical_status,
                -- One member seen and the rest never: a strong hint, but still
                -- a hint. Free play is not a controlled input.
                single_candidate = (#seen_ids == 1) and seen_ids[1] or nil,
            }
        end
    end
    table.sort(groups, function(a, b) return a.display_group < b.display_group end)

    local coverage = (known_count > 0) and (seen_known / known_count) or 0

    local report = {
        probe = "D.catalog_audit",
        character = catalog.character,
        ac_sha256 = catalog.ac_sha256,
        bcm_sha256 = catalog.bcm_sha256,
        catalogued_action_ids = known_count,
        observed_action_ids = seen_total,
        matched = seen_known,
        coverage = coverage,
        unknown_observed = unknown,
        unseen_standalone = unseen_standalone,
        ambiguous_groups = groups,
    }

    -- The judgement, stated rather than left to be inferred by someone reading
    -- a JSON file on another machine.
    local min_observed = opts.min_observed or 20
    if seen_total < min_observed then
        report.verdict = ("only %d distinct action ids observed - play for longer before "
            .. "reading anything into this"):format(seen_total)
        report.conclusive = false
    elseif seen_known == 0 then
        report.verdict = "NOT ONE observed action id is in the catalog - the catalog is for a "
            .. "different character, or the game data has moved"
        report.conclusive = true
    elseif #unknown > seen_known then
        report.verdict = ("%d observed ids are unknown to the catalog against %d matched - "
            .. "suspicious; check the character and the patch")
            :format(#unknown, seen_known)
        report.conclusive = true
    else
        report.verdict = ("%d of %d observed ids matched the catalog (%d%% of catalogued ids seen)")
            :format(seen_known, seen_total, math.floor(coverage * 100 + 0.5))
        report.conclusive = true
    end

    return report
end

return M
