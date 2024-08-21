using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestPixelSendCRT : MonoBehaviour
{
    [SerializeField]
    private Material mat;

    [SerializeField]
    private float tickWait = 1.0f;

    // Start is called before the first frame update
    void Start()
    {
        InvokeRepeating(nameof(WritePixel), 1.0f, tickWait);
    }

    void WritePixel()
    {
        Debug.Log("WritePixel");
        mat.SetFloat("_V0", Random.value);
        mat.SetFloat("_V1", Random.value);
        mat.SetFloat("_V2", Random.value);
        mat.SetFloat("_V3", Random.value);
        mat.SetFloat("_V4", Random.value);
        mat.SetFloat("_V5", Random.value);
        mat.SetFloat("_V6", Random.value);
        mat.SetFloat("_V7", Random.value);
        mat.SetFloat("_V8", Random.value);

        mat.SetFloat("_V9", Random.value);
        mat.SetFloat("_VA", Random.value);
        mat.SetFloat("_VB", Random.value);
        mat.SetFloat("_VC", Random.value);
        mat.SetFloat("_VD", Random.value);
        mat.SetFloat("_VE", Random.value);
        mat.SetFloat("_VF", Random.value);

        int WR = (mat.GetInteger("_CLK") != 0) ? 0 : 1;
        mat.SetInteger("_CLK", WR);
    }
}
