<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:D="DAV:" exclude-result-prefixes="D">
    <xsl:output method="html" encoding="UTF-8" />
    <xsl:template name="get-extension">
        <xsl:param name="path" />
        <xsl:choose>
            <xsl:when test="contains($path, '/')">
                <xsl:call-template name="get-extension">
                    <xsl:with-param name="path" select="substring-after($path, '/')" />
                </xsl:call-template>
            </xsl:when>
            <xsl:when test="contains($path, '.')">
                <xsl:call-template name="get-extension">
                    <xsl:with-param name="path" select="substring-after($path, '.')" />
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$path" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="D:multistatus">
        <xsl:text disable-output-escaping="yes">&lt;?xml version="1.0" encoding="utf-8" ?&gt;</xsl:text>
        <D:multistatus xmlns:D="DAV:">
            <xsl:copy-of select="*" />
        </D:multistatus>
    </xsl:template>
    <xsl:template match="/list">
        <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
        <html>
            <head>
                <link rel="icon" href="/.assets/favicon.svg" sizes="any" type="image/svg+xml" />
                <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.5/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SgOJa3DmI69IUzQ2PVdRZhwQ+dy64/BUtbMJw1MZ8t5HZApcHrRKUc4W0kG879m7" crossorigin="anonymous" />
                <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css" rel="stylesheet" />
                <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.5/dist/js/bootstrap.bundle.min.js" integrity="sha384-k6d4wzSIapyDyv1kpU366/PK5hCdSbCRGRCMv+eplOQJWyd1fbcAu9OCUj5zNLiq" crossorigin="anonymous"></script>
                <link href="/.assets/default.css" rel="stylesheet" />
                <script src="/.assets/default.js"></script>
            </head>
            <body>
                <div class="container">
                    <nav id="breadcrumbs">
                        <ul>
                            <li>
                                <a href="/">
                                    <i class="bi bi-house-fill"></i>
                                </a>
                            </li>
                        </ul>
                    </nav>
                    <table class="table table-striped table-hover w-auto">
                        <thead>
                            <tr>
                                <th>name</th>
                                <th>size</th>
                                <th>date</th>
                            </tr>
                            <tr class="parent-link">
                                <th>
                                    <a href="../">
                                        <i class="bi bi-file-arrow-up-fill"></i>
                                    </a>
                                </th>
                                <th></th>
                                <th></th>
                            </tr>
                        </thead>
                        <tbody>
                            <xsl:for-each select="directory">
                                <xsl:variable name="date">
                                    <xsl:value-of select="substring(@mtime,1,4)" />
                                    <xsl:text>-</xsl:text>
                                    <xsl:value-of select="substring(@mtime,6,2)" />
                                    <xsl:text>-</xsl:text>
                                    <xsl:value-of select="substring(@mtime,9,2)" />
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of select="substring(@mtime,12,2)" />
                                    <xsl:text>:</xsl:text>
                                    <xsl:value-of select="substring(@mtime,15,2)" />
                                    <xsl:text>:</xsl:text>
                                    <xsl:value-of select="substring(@mtime,18,2)" />
                                </xsl:variable>
                                <tr>
                                    <td>
                                        <a href="{.}/">
                                            <i class="bi bi-folder-fill"></i>
                                            <xsl:value-of select="." />
                                        </a>
                                    </td>
                                    <td></td>
                                    <td>
                                        <a href="{.}/">
                                            <xsl:value-of select="$date" />
                                        </a>
                                    </td>
                                </tr>
                            </xsl:for-each>
                            <xsl:for-each select="file">
                                <xsl:variable name="size">
                                    <xsl:if test="string-length(@size) &gt; 0">
                                        <xsl:if test="number(@size) &gt; 0">
                                            <xsl:choose>
                                                <xsl:when test="round(@size div 1024) &lt; 1">
                                                    <xsl:value-of select="@size" /> b
                                                </xsl:when>
                                                <xsl:when test="round(@size div (1024 * 1024)) &lt; 1">
                                                    <xsl:value-of select="format-number((@size div 1024), '0.0')" /> kb
                                                </xsl:when>
                                                <xsl:when test="round(@size div (1024 * 1024 * 1024)) &lt; 1">
                                                    <xsl:value-of select="format-number((@size div (1024 * 1024)), '0.0')" /> mb
                                                </xsl:when>
                                                <xsl:when test="round(@size div (1024 * 1024 * 1024 * 1024)) &lt; 1">
                                                    <xsl:value-of select="format-number((@size div (1024 * 1024 * 1024)), '0.0')" /> gb
                                                </xsl:when>
                                                <xsl:otherwise>
                                                    <xsl:value-of select="format-number((@size div (1024 * 1024 * 1024 * 1024)), '0.00')" /> tb
                                                </xsl:otherwise>
                                            </xsl:choose>
                                        </xsl:if>
                                    </xsl:if>
                                </xsl:variable>
                                <xsl:variable name="date">
                                    <xsl:value-of select="substring(@mtime,1,4)" />
                                    <xsl:text>-</xsl:text>
                                    <xsl:value-of select="substring(@mtime,6,2)" />
                                    <xsl:text>-</xsl:text>
                                    <xsl:value-of select="substring(@mtime,9,2)" />
                                    <xsl:text> </xsl:text>
                                    <xsl:value-of select="substring(@mtime,12,2)" />
                                    <xsl:text>:</xsl:text>
                                    <xsl:value-of select="substring(@mtime,15,2)" />
                                    <xsl:text>:</xsl:text>
                                    <xsl:value-of select="substring(@mtime,18,2)" />
                                </xsl:variable>
                                <xsl:variable name="extn">
                                    <xsl:call-template name="get-extension">
                                        <xsl:with-param name="path" select="translate(., 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', 'abcdefghijklmnopqrstuvwxyz')" />
                                    </xsl:call-template>
                                </xsl:variable>
                                <xsl:variable name="icon">
                                    <xsl:choose>
                                        <xsl:when test="contains('|mp3|wav|', concat('|', $extn, '|'))">
                                            bi bi-cassette-fill
                                        </xsl:when>
                                        <xsl:when test="contains('|avi|mov|mp4|', concat('|', $extn, '|'))">
                                            bi bi-play-btn-fill
                                        </xsl:when>
                                        <xsl:otherwise>
                                            bi bi-file-earmark-fill
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:variable>
                                <tr>
                                    <td>
                                        <a href="{.}">
                                            <i class="{$icon}"></i>
                                            <xsl:value-of select="." />
                                        </a>
                                    </td>
                                    <td class="text-end">
                                        <xsl:value-of select="$size" />
                                    </td>
                                    <td>
                                        <xsl:value-of select="$date" />
                                    </td>
                                </tr>
                            </xsl:for-each>
                        </tbody>
                    </table>
                </div>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
