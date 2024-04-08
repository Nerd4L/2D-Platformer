using JetBrains.Annotations;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

public class ControllerScript : MonoBehaviour
{
    private Rigidbody2D kirbyBody;

    public Vector2 moveInput;
    private Vector3 velocity = Vector3.zero;

    private bool facingRight = true;                                            // For determining which way the player is currently facing.

    private float blinkInterval = 100f;
    private float blinkTimer = 0f;

    const float groundedRadius = .1f;                                          // Distance of the overlap to determine if grounded
    [SerializeField] private float coyoteTimeCounter;
    [SerializeField] private float coyoteTime = 0.5f;

    private bool hasPressedJump = false;
    private bool allowedToDoubleJump = false;
    private bool hasLetGoJump = false;

    [SerializeField] private Transform groundCheck;

    private LayerMask whatIsGround;
    private LayerMask whatIsPlatform;

    [SerializeField] private bool onGround;                                     // Whether or not the player is grounded
    [SerializeField] private bool onPlatform;

    private bool ignorePlatforms;

    [Range(0, .3f)][SerializeField] private float movementSmoothing = .1f;      // How much to smooth out the movement

    [Header("Events")]
    [Space]

    public UnityEvent OnFallingEvent;
    public UnityEvent OnGroundedEvent;
    public UnityEvent OnBlinkEvent;
    public UnityEvent OnJumpEvent;

    [System.Serializable]
    public class BoolEvent : UnityEvent<bool> { }

    private void Awake()
    {
        kirbyBody = GetComponent<Rigidbody2D>();
        whatIsGround = LayerMask.GetMask("Ground");
        whatIsPlatform = LayerMask.GetMask("Platforms");

        OnFallingEvent ??= new UnityEvent();
        OnGroundedEvent ??= new UnityEvent();
        OnBlinkEvent ??= new UnityEvent();
        OnJumpEvent ??= new UnityEvent();

    }

    private void FixedUpdate()
    {
        onGround = false;
        onPlatform = false;

        // The player is grounded if a circlecast to the groundcheck position hits anything designated as ground
        // This can be done using layers instead but Sample Assets will not overwrite your project settings.
        Collider2D[] groundColliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsGround);
        for (int i = 0; i < groundColliders.Length; i++)
        {
            if (groundColliders[i].gameObject != gameObject)
            {
                // Grounded on Ground
                onGround = true;
            }
        }

        Collider2D[] platformColliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsPlatform);
        for (int j = 0; j < platformColliders.Length; j++)
        {
            if (platformColliders[j].gameObject != gameObject)
            {
                // Grounded on Platform
                onPlatform = true;
            }
        }

        if (onGround || (onPlatform && !ignorePlatforms))
        {
            allowedToDoubleJump = true;
            OnGroundedEvent.Invoke();
        }

        //Collider2D[] platformColliders = Physics2D.OverlapCircleAll(bodyCheck.position, 0.49f, whatIsPlatform);
        //for (int j = 0; j < platformColliders.Length; j++)
        //{
        //    if (platformColliders[j].gameObject != gameObject)
        //    {
        //        // Grounded on platform
        //        insidePlatform = true;
        //        OnGroundedEvent.Invoke();
        //        allowedToDoubleJump = true;

        //    }
        //}

        // If on the ground and not moving up or down. Set Coyote Time and blink
        if (Mathf.Abs(kirbyBody.velocity.y) < 0.01f)
        {
            coyoteTimeCounter = coyoteTime;

            // Blink
            blinkTimer += Time.deltaTime;
            float blinkValue = Mathf.Floor(blinkInterval * UnityEngine.Random.value);
            if (blinkTimer > blinkValue)
            {
                OnBlinkEvent.Invoke();
                blinkTimer = 0;
            }
        }
        else
        {
            coyoteTimeCounter -= Time.deltaTime;
        }


        // Check if Falling
        if (kirbyBody.velocity.y < -0.01f)
        {
            OnFallingEvent.Invoke();
        }
    }

    //private void OnCollisionEnter2D(Collision2D collision)
    //{
    //    if (collision.gameObject.CompareTag("OneWayPlatform"))
    //    {
    //        //currentOneWayPlatform = collision.gameObject;
    //        IgnorePlatforms(true);
    //    }
    //}

    //private void OnCollisionExit2D(Collision2D collision)
    //{
    //    if (collision.gameObject.CompareTag("OneWayPlatform"))
    //    {
    //        //currentOneWayPlatform = null;
    //        IgnorePlatforms(false);
    //    }
    //}

    //private IEnumerator DisableCollision()
    //{
    //    BoxCollider2D platformCollider = currentOneWayPlatform.GetComponent<BoxCollider2D>();
    //    Physics2D.IgnoreCollision(kirbyBoxCollider, platformCollider);
    //}


    public void Move(float move, bool jump, float jumpForce, bool crouch)
    {
        // Move the character by finding the target velocity
        Vector3 targetVelocity = new Vector2(move * 10f, kirbyBody.velocity.y);
        // And then smoothing it out and applying it to the character
        kirbyBody.velocity = Vector3.SmoothDamp(kirbyBody.velocity, targetVelocity, ref velocity, movementSmoothing);

        // Flip the player
        if (move > 0 && !facingRight)
            Flip();
        else if (move < 0 && facingRight)
            Flip();

        if (jump && !hasPressedJump)
        {
            hasPressedJump = true;
            if (onGround || onPlatform)
            {
                Jump(jumpForce, false);
            }
        }


        if (!jump)
        {
            hasPressedJump = false;
        }

        //if (!crouch && kirbyBody.velocity.y <= 0f)
        //if (!crouch)
        //{
        //    if (!onPlatform)
        //    {
        //        IgnorePlatforms();
        //    }
        //}

        if (crouch || kirbyBody.velocity.y > 0.001f)
        {
            StartCoroutine(IgnorePlatforms());
        }
        //else if (!crouch && ignorePlatforms && onPlatform)


        //if (jump && (Mathf.Abs(kirbyBody.velocity.y) < 0.0001f))
        //if(jump && !hasPressedJump)
        //{
        //    hasPressedJump = true;

        //    if (onGround)
        //    {
        //        Jump(jumpForce, false);
        //    }


        //    //coyoteTimeCounter = 0f;
        //    //if (coyoteTimeCounter < 0)
        //    //{

        //    //}

        //}



        //if (jump && (Mathf.Abs(kirbyBody.velocity.y) < 0.0001f || coyoteTimeCounter < 0))
        //{

        //}
    }

    private IEnumerator IgnorePlatforms()
    {
        Physics2D.IgnoreLayerCollision(3, 7, true);
        ignorePlatforms = true;
        yield return new WaitForSeconds(0.25f);
        Physics2D.IgnoreLayerCollision(3, 7, false);
        ignorePlatforms = false;
    }

    private void Flip()
    {
        // Rotate 180 on Y-axis
        if (facingRight)
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 180f, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        else
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 0, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }


        // Switch the way the player is labelled as facing.
        facingRight = !facingRight;
    }

    private void Jump(float addJumpForce, bool reset)
    {
        // Add a vertical force to the player.
        if (reset)
        {
            Vector2 oldVector = kirbyBody.velocity;
            kirbyBody.velocity = new Vector2(oldVector.x, 0f);
        }

        kirbyBody.AddForce(new Vector2(0f, addJumpForce));
        OnJumpEvent.Invoke();
    }
}
