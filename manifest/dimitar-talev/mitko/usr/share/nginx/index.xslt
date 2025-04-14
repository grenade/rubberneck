<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:template match="/">
        <html>
            <head>
                <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.5/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-SgOJa3DmI69IUzQ2PVdRZhwQ+dy64/BUtbMJw1MZ8t5HZApcHrRKUc4W0kG879m7" crossorigin="anonymous">
                <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.5/dist/js/bootstrap.bundle.min.js" integrity="sha384-k6d4wzSIapyDyv1kpU366/PK5hCdSbCRGRCMv+eplOQJWyd1fbcAu9OCUj5zNLiq" crossorigin="anonymous"></script>
            </head>
            <body>
                <table class="table table-striped">
                    <thead>
                        <tr>
                            <th>file</th>
                            <th>size</th>
                            <th>date</th>
                        </tr>
                    </thead>
                    <tbody>
                        <xsl:for-each select="list/*">
                            <xsl:sort select="@mtime" />
                            <xsl:variable name="name">
                                <xsl:value-of select="."/>
                            </xsl:variable>
                            <xsl:variable name="size">
                                <xsl:if test="string-length(@size) &gt; 0">
                                    <xsl:if test="number(@size) &gt; 0">
                                        <xsl:choose>
                                            <xsl:when test="round(@size div 1024) &lt; 1"><xsl:value-of select="@size" /></xsl:when>
                                            <xsl:when test="round(@size div 1048576) &lt; 1"><xsl:value-of select="format-number((@size div 1024), '0.0')" />K</xsl:when>
                                            <xsl:otherwise><xsl:value-of select="format-number((@size div 1048576), '0.00')" />M</xsl:otherwise>
                                        </xsl:choose>
                                    </xsl:if>
                                </xsl:if>
                            </xsl:variable>
                            <xsl:variable name="date">
                                <xsl:value-of select="substring(@mtime,9,2)"/>-<xsl:value-of select="substring(@mtime,6,2)"/>-<xsl:value-of select="substring(@mtime,1,4)"/><xsl:text> </xsl:text>
                                <xsl:value-of select="substring(@mtime,12,2)"/>:<xsl:value-of select="substring(@mtime,15,2)"/>:<xsl:value-of select="substring(@mtime,18,2)"/>
                            </xsl:variable>
                            <tr>
                                <td>
                                    <a href="{$name}"><xsl:value-of select="."/></a>
                                </td>
                                <td align="right">
                                    <xsl:value-of select="$size"/>
                                </td>
                                <td>
                                    <xsl:value-of select="$date"/>
                                </td>
                            </tr>
                        </xsl:for-each>
                    </tbody>
                </table>
            </body>
        </html>
    </xsl:template>
</xsl:stylesheet>
