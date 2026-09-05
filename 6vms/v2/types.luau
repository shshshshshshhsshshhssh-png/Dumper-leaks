--!strict

export type AstExpression = {
    kind: string,
    data: {
        [any]: any
    },
    stat: boolean?
}

export type Spied = {
    [any]: any
}

export type AstBlock = {
    kind: "block",
    stat: true,
    data: {
        statements: { any }
    }
}

return {}